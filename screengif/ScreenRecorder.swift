import Foundation
import Combine
import ScreenCaptureKit
import CoreMedia
import CoreImage
import Cocoa

enum RecordingState: Equatable {
    case idle
    case selectingRegion
    case recording
    case encoding
}

@MainActor
final class ScreenRecorder: NSObject, ObservableObject {

    @Published var state: RecordingState = .idle
    @Published var recordingDuration: TimeInterval = 0
    @Published var lastSavedURL: URL?
    @Published var errorMessage: String?

    private var stream: SCStream?
    private var capturedFrames: [CGImage] = []
    private let ciContext = CIContext()
    private var timer: Timer?
    private var recordingStart: Date?
    private let regionSelector = RegionSelector()
    private let hotkeyManager = HotkeyManager()

    private var captureRegion: CGRect?
    private var captureDisplay: SCDisplay?
    private var borderWindow: RecordingBorderWindow?

    private let fps: Int = 15
    private let maxGIFWidth: Int = 640

    override init() {
        super.init()
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
        case .selectingRegion, .encoding:
            break
        }
    }

    func recordFullScreen() {
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let display = content.displays.first else {
                    errorMessage = "Nenhum display encontrado"
                    return
                }
                let filter = SCContentFilter(display: display, excludingWindows: [])
                self.captureDisplay = display
                self.captureRegion = nil
                try await beginRecording(filter: filter, width: display.width, height: display.height)
            } catch {
                errorMessage = "Erro ao iniciar gravação: \(error.localizedDescription)"
            }
        }
    }

    func startRegionSelection() {
        state = .selectingRegion
        regionSelector.selectRegion { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                guard let (rect, screen) = result else {
                    self.state = .idle
                    return
                }
                await self.startRecordingRegion(rect: rect, screen: screen)
            }
        }
    }

    func stopRecording() {
        guard state == .recording else { return }
        state = .encoding
        timer?.invalidate()
        timer = nil
        borderWindow?.orderOut(nil)
        borderWindow = nil

        Task {
            do {
                try await stream?.stopCapture()
                stream = nil
                await encodeAndSave()
            } catch {
                errorMessage = "Erro ao parar gravação: \(error.localizedDescription)"
                state = .idle
            }
        }
    }

    // MARK: - Private

    private func startRecordingRegion(rect: CGRect, screen: NSScreen) async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

            // Find the matching display
            guard let display = content.displays.first(where: { display in
                let displayFrame = CGRect(
                    x: display.frame.origin.x,
                    y: display.frame.origin.y,
                    width: CGFloat(display.width),
                    height: CGFloat(display.height)
                )
                return displayFrame.intersects(screen.frame)
            }) else {
                errorMessage = "Display não encontrado"
                state = .idle
                return
            }

            self.captureDisplay = display
            self.captureRegion = rect

            // Calculate capture dimensions from the region
            let width = Int(rect.width)
            let height = Int(rect.height)

            let filter = SCContentFilter(display: display, excludingWindows: [])
            try await beginRecording(filter: filter, width: width, height: height)
        } catch {
            errorMessage = "Erro ao iniciar gravação: \(error.localizedDescription)"
            state = .idle
        }
    }

    private func beginRecording(filter: SCContentFilter, width: Int, height: Int) async throws {
        capturedFrames.removeAll()

        let config = SCStreamConfiguration()
        config.width = width
        config.height = height
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(fps))
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = true

        // If we have a region, set the source rect
        if let region = captureRegion, let display = captureDisplay {
            // Convert from screen coordinates to display-relative coordinates
            // ScreenCaptureKit uses top-left origin
            let displayFrame = display.frame
            let sourceX = region.origin.x - displayFrame.origin.x
            // Flip Y: NSScreen uses bottom-left, SCKit uses top-left
            let screenHeight = CGFloat(display.height)
            let sourceY = screenHeight - (region.origin.y - displayFrame.origin.y) - region.height

            config.sourceRect = CGRect(x: sourceX, y: sourceY, width: region.width, height: region.height)
            config.width = Int(region.width)
            config.height = Int(region.height)
        }

        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .global(qos: .userInteractive))
        try await stream.startCapture()

        self.stream = stream
        state = .recording
        recordingStart = Date()
        recordingDuration = 0

        // Show border around recorded region
        if let region = captureRegion {
            borderWindow = RecordingBorderWindow(region: region)
            borderWindow?.makeKeyAndOrderFront(nil)
        }

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self, let start = self.recordingStart else { return }
                self.recordingDuration = Date().timeIntervalSince(start)
            }
        }
    }

    private func encodeAndSave() async {
        let frames = capturedFrames
        capturedFrames.removeAll()

        guard !frames.isEmpty else {
            errorMessage = "Nenhum frame capturado"
            state = .idle
            return
        }

        let desktopURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop")

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "ScreenGif_\(formatter.string(from: Date())).gif"
        let fileURL = desktopURL.appendingPathComponent(filename)

        let fps = self.fps
        let maxWidth = self.maxGIFWidth
        let success = await Task.detached(priority: .userInitiated) {
            GIFEncoder.encode(
                frames: frames,
                frameDelay: 1.0 / Double(fps),
                maxWidth: maxWidth,
                to: fileURL
            )
        }.value

        if success {
            lastSavedURL = fileURL
            // Open in Finder
            NSWorkspace.shared.activateFileViewerSelecting([fileURL])
        } else {
            errorMessage = "Falha ao criar GIF"
        }

        state = .idle
    }
}

// MARK: - SCStreamDelegate

extension ScreenRecorder: SCStreamDelegate {
    nonisolated func stream(_ stream: SCStream, didStopWithError error: any Error) {
        Task { @MainActor in
            errorMessage = "Stream parou: \(error.localizedDescription)"
            state = .idle
        }
    }
}

// MARK: - SCStreamOutput

extension ScreenRecorder: SCStreamOutput {
    nonisolated func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of outputType: SCStreamOutputType
    ) {
        guard outputType == .screen else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }

        Task { @MainActor in
            if state == .recording {
                capturedFrames.append(cgImage)
            }
        }
    }
}
