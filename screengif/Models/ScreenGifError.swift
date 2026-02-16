import Foundation

enum ScreenGifError: LocalizedError {
    case noDisplayFound
    case displayNotFound
    case captureStartFailed(underlying: Error)
    case captureStopFailed(underlying: Error)
    case streamStopped(underlying: Error)
    case noFramesCaptured
    case gifEncodingFailed

    var errorDescription: String? {
        switch self {
        case .noDisplayFound:
            "No display found"
        case .displayNotFound:
            "Display not found"
        case .captureStartFailed(let error):
            "Failed to start recording: \(error.localizedDescription)"
        case .captureStopFailed(let error):
            "Failed to stop recording: \(error.localizedDescription)"
        case .streamStopped(let error):
            "Stream stopped: \(error.localizedDescription)"
        case .noFramesCaptured:
            "No frames captured"
        case .gifEncodingFailed:
            "Failed to create GIF"
        }
    }
}
