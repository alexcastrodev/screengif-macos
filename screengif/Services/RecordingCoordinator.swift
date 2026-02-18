import Foundation
import ScreenCaptureKit
import Cocoa
import os
import Combine

@MainActor
final class RecordingCoordinator: NSObject, ObservableObject {

    // MARK: - Published State

    @Published var state: RecordingState = .idle
    @Published var recordingDuration: TimeInterval = 0
    @Published var lastSavedURL: URL?
    @Published var errorMessage: String?

    // MARK: - Dependencies

    let settings: AppSettings
    private let captureService: CaptureService
    private let frameBuffer: FrameBuffer
    private let regionSelector = RegionSelector()
    private let hotkeyManager = HotkeyManager()
    private let logger = Logger(subsystem: "com.lekito.screengif", category: "RecordingCoordinator")

    // MARK: - Internal State

    private var timer: Timer?
    private var recordingStart: Date?
    var captureRegion: CGRect?
    private var captureDisplay: SCDisplay?
    private var backdropWindows: [RecordingBackdropWindow] = []
    
    override init() {
        self.settings = AppSettings()
        self.frameBuffer = FrameBuffer()
        self.captureService = CaptureService(frameBuffer: frameBuffer)
        super.init()

        captureService.onStreamError = { [weak self] error in
            self?.handleStreamError(error)
        }

        hotkeyManager.register { [weak self] in
            Task { @MainActor in
                self?.toggleRecording()
            }
        }
    }

    // MARK: - Public

    func toggleRecording() {
        switch state {
        case .idle:
            startRegionSelection()
        case .recording:
            stopRecording()
        case .selectingRegion:
            cancelSelection()
        case .encoding:
            break
        }
    }
    
    func cancelSelection() {
        guard state == .selectingRegion else { return }
        regionSelector.cancel()
    }

    func recordFullScreen() {
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let display = content.displays.first else {
                    setError(.noDisplayFound)
                    return
                }
                
                // Exclude self application
                let currentPID = ProcessInfo.processInfo.processIdentifier
                let selfApp = content.applications.first { $0.processID == currentPID }
                let excludedApps = selfApp != nil ? [selfApp!] : []
                
                let filter = SCContentFilter(display: display, excludingApplications: excludedApps, exceptingWindows: [])
                self.captureDisplay = display
                self.captureRegion = nil
                try await beginRecording(filter: filter, width: display.width, height: display.height)
            } catch {
                setError(.captureStartFailed(underlying: error))
            }
        }
    }

    func startRegionSelection() {
        state = .selectingRegion
        logger.info("Region selection started")
        regionSelector.selectRegion { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                guard let (rect, screen) = result else {
                    self.state = .idle
                    self.logger.info("Region selection cancelled")
                    return
                }
                self.logger.info("Region selected: \(rect.debugDescription)")
                await self.startRecordingRegion(rect: rect, screen: screen)
            }
        }
    }

    func stopRecording() {
        guard state == .recording else { return }
        state = .encoding
        logger.info("Stopping recording")
        timer?.invalidate()
        timer = nil

        for w in backdropWindows { w.orderOut(nil) }
        backdropWindows.removeAll()

        Task {
            do {
                try await captureService.stopCapture()
                await encodeAndSave()
            } catch {
                setError(.captureStopFailed(underlying: error))
                state = .idle
            }
        }
    }

    // MARK: - Private

    private func startRecordingRegion(rect: CGRect, screen: NSScreen) async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

            guard let display = content.displays.first(where: { display in
                let displayFrame = CGRect(
                    x: display.frame.origin.x,
                    y: display.frame.origin.y,
                    width: CGFloat(display.width),
                    height: CGFloat(display.height)
                )
                return displayFrame.intersects(screen.frame)
            }) else {
                setError(.displayNotFound)
                state = .idle
                return
            }

            self.captureDisplay = display
            self.captureRegion = rect

            let width = Int(rect.width)
            let height = Int(rect.height)
            
            // Exclude self application
            let currentPID = ProcessInfo.processInfo.processIdentifier
            let selfApp = content.applications.first { $0.processID == currentPID }
            let excludedApps = selfApp != nil ? [selfApp!] : []

            let filter = SCContentFilter(display: display, excludingApplications: excludedApps, exceptingWindows: [])
            try await beginRecording(filter: filter, width: width, height: height)
        } catch {
            setError(.captureStartFailed(underlying: error))
            state = .idle
        }
    }

    private func beginRecording(filter: SCContentFilter, width: Int, height: Int) async throws {
        var sourceRect: CGRect? = nil

        if let region = captureRegion, let display = captureDisplay {
            let displayFrame = display.frame
            let sourceX = region.origin.x - displayFrame.origin.x
            let screenHeight = CGFloat(display.height)
            let sourceY = screenHeight - (region.origin.y - displayFrame.origin.y) - region.height
            sourceRect = CGRect(x: sourceX, y: sourceY, width: region.width, height: region.height)
        }

        try await captureService.startCapture(
            filter: filter,
            width: width,
            height: height,
            fps: settings.fps,
            showCursor: settings.showCursor,
            sourceRect: sourceRect
        )

        state = .recording
        recordingStart = Date()
        recordingDuration = 0

        if let region = captureRegion {
            for screen in NSScreen.screens {
                let backdrop = RecordingBackdropWindow(screen: screen, clearRect: region)
                backdrop.orderFrontRegardless()
                backdropWindows.append(backdrop)
            }
        }

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self, let start = self.recordingStart else { return }
                self.recordingDuration = Date().timeIntervalSince(start)
            }
        }

        logger.info("Recording started")
    }

    private func encodeAndSave() async {
        let frames = frameBuffer.drain()

        guard !frames.isEmpty else {
            setError(.noFramesCaptured)
            state = .idle
            return
        }

        logger.info("Encoding \(frames.count) frames")

        let outputDir = settings.outputDirectory
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "ScreenGif_\(formatter.string(from: Date())).gif"
        let fileURL = outputDir.appendingPathComponent(filename)

        let fps = settings.fps
        let maxWidth = settings.maxGIFWidth
        let speed = settings.recordingSpeed

        do {
            try await Task.detached(priority: .userInitiated) {
                try GIFEncoder.encode(
                    frames: frames,
                    frameDelay: (1.0 / Double(fps)) / speed,
                    maxWidth: maxWidth,
                    to: fileURL
                )
            }.value

            lastSavedURL = fileURL
            NSWorkspace.shared.activateFileViewerSelecting([fileURL])
            logger.info("GIF saved: \(fileURL.lastPathComponent)")
        } catch {
            setError(.gifEncodingFailed)
        }

        state = .idle
    }

    private func handleStreamError(_ error: Error) {
        setError(.streamStopped(underlying: error))
        state = .idle
    }

    private func setError(_ error: ScreenGifError) {
        logger.error("\(error.localizedDescription)")
        errorMessage = error.errorDescription
    }
}
