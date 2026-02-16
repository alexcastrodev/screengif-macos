import Foundation
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers
import os

nonisolated struct GIFEncoder {

    private static let logger = Logger(subsystem: "com.lekito.screengif", category: "GIFEncoder")

    static func encode(
        frames: [CGImage],
        frameDelay: Double = 1.0 / 15.0,
        loopCount: Int = 0,
        maxWidth: Int = 640,
        to url: URL
    ) throws {
        guard !frames.isEmpty else { throw ScreenGifError.noFramesCaptured }

        logger.info("Encoding \(frames.count) frames to \(url.lastPathComponent)")

        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.gif.identifier as CFString,
            frames.count,
            nil
        ) else { throw ScreenGifError.gifEncodingFailed }

        let gifProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFLoopCount as String: loopCount
            ]
        ]
        CGImageDestinationSetProperties(destination, gifProperties as CFDictionary)

        let frameProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFDelayTime as String: frameDelay
            ]
        ]

        for frame in frames {
            let resized = resizeIfNeeded(frame, maxWidth: maxWidth)
            CGImageDestinationAddImage(destination, resized, frameProperties as CFDictionary)
        }

        guard CGImageDestinationFinalize(destination) else {
            throw ScreenGifError.gifEncodingFailed
        }

        logger.info("GIF encoded successfully: \(url.lastPathComponent)")
    }

    private static func resizeIfNeeded(_ image: CGImage, maxWidth: Int) -> CGImage {
        guard image.width > maxWidth else { return image }

        let scale = Double(maxWidth) / Double(image.width)
        let newWidth = maxWidth
        let newHeight = Int(Double(image.height) * scale)

        guard let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return image }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))

        return context.makeImage() ?? image
    }
}
