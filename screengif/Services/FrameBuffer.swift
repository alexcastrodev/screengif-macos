import Foundation
import CoreGraphics
import os

nonisolated final class FrameBuffer: @unchecked Sendable {

    private let lock = NSLock()
    private var frames: [CGImage] = []
    private let maxFrameCount: Int
    private let logger = Logger(subsystem: "com.lekito.screengif", category: "FrameBuffer")

    init(maxFrameCount: Int = 1800) {
        self.maxFrameCount = maxFrameCount
    }

    func append(_ image: CGImage) {
        lock.lock()
        defer { lock.unlock() }

        if frames.count >= maxFrameCount {
            logger.warning("Frame buffer full (\(self.maxFrameCount) frames). Dropping oldest frame.")
            frames.removeFirst()
        }
        frames.append(image)
    }

    func drain() -> [CGImage] {
        lock.lock()
        defer { lock.unlock() }

        let result = frames
        frames.removeAll()
        return result
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return frames.count
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        frames.removeAll()
    }
}
