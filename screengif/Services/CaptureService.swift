import ScreenCaptureKit
import CoreMedia
import CoreImage
import os

nonisolated final class CaptureService: NSObject, @unchecked Sendable {

    private var stream: SCStream?
    private let ciContext = CIContext()
    private let frameBuffer: FrameBuffer
    private let logger = Logger(subsystem: "com.lekito.screengif", category: "CaptureService")

    var onStreamError: (@MainActor (Error) -> Void)?

    private(set) var isCapturing = false

    init(frameBuffer: FrameBuffer) {
        self.frameBuffer = frameBuffer
        super.init()
    }

    @MainActor
    func startCapture(
        filter: SCContentFilter,
        width: Int,
        height: Int,
        fps: Int,
        showCursor: Bool,
        sourceRect: CGRect? = nil
    ) async throws {
        frameBuffer.clear()

        let config = SCStreamConfiguration()
        config.width = width
        config.height = height
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(fps))
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = showCursor

        if let sourceRect {
            config.sourceRect = sourceRect
            config.width = Int(sourceRect.width)
            config.height = Int(sourceRect.height)
        }

        let newStream = SCStream(filter: filter, configuration: config, delegate: self)
        try newStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .global(qos: .userInteractive))

        logger.info("Starting capture: \(width)x\(height) @ \(fps)fps")
        try await newStream.startCapture()

        self.stream = newStream
        self.isCapturing = true
    }

    @MainActor
    func stopCapture() async throws {
        guard let stream else { return }
        logger.info("Stopping capture")
        try await stream.stopCapture()
        self.stream = nil
        self.isCapturing = false
    }
}

// MARK: - SCStreamDelegate

extension CaptureService: SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: any Error) {
        logger.error("Stream stopped with error: \(error.localizedDescription)")
        Task { @MainActor in
            self.isCapturing = false
            self.onStreamError?(error)
        }
    }
}

// MARK: - SCStreamOutput

extension CaptureService: SCStreamOutput {
    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of outputType: SCStreamOutputType
    ) {
        guard outputType == .screen else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }

        frameBuffer.append(cgImage)
    }
}
