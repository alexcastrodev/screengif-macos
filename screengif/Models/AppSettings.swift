import Foundation

@Observable
final class AppSettings {

    private enum Key {
        static let fps = "settings.fps"
        static let maxGIFWidth = "settings.maxGIFWidth"
        static let recordingSpeed = "settings.recordingSpeed"
        static let outputDirectory = "settings.outputDirectory"
        static let showCursor = "settings.showCursor"
    }

    static let defaultFPS = 15
    static let defaultMaxGIFWidth = 3840
    static let defaultRecordingSpeed = 1.0
    static let defaultShowCursor = true

    private let defaults: UserDefaults

    var fps: Int {
        didSet { defaults.set(fps, forKey: Key.fps) }
    }

    var maxGIFWidth: Int {
        didSet { defaults.set(maxGIFWidth, forKey: Key.maxGIFWidth) }
    }

    var recordingSpeed: Double {
        didSet { defaults.set(recordingSpeed, forKey: Key.recordingSpeed) }
    }

    var outputDirectory: URL {
        didSet { defaults.set(outputDirectory.path, forKey: Key.outputDirectory) }
    }

    var showCursor: Bool {
        didSet { defaults.set(showCursor, forKey: Key.showCursor) }
    }

    nonisolated init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let storedFPS = defaults.integer(forKey: Key.fps)
        self.fps = storedFPS > 0 ? storedFPS : Self.defaultFPS

        let storedWidth = defaults.integer(forKey: Key.maxGIFWidth)
        self.maxGIFWidth = storedWidth > 0 ? storedWidth : Self.defaultMaxGIFWidth

        let storedSpeed = defaults.double(forKey: Key.recordingSpeed)
        self.recordingSpeed = storedSpeed > 0 ? storedSpeed : Self.defaultRecordingSpeed

        self.showCursor = defaults.object(forKey: Key.showCursor) != nil
            ? defaults.bool(forKey: Key.showCursor)
            : Self.defaultShowCursor

        if let path = defaults.string(forKey: Key.outputDirectory),
           FileManager.default.fileExists(atPath: path) {
            self.outputDirectory = URL(fileURLWithPath: path)
        } else {
            self.outputDirectory = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Desktop")
        }
    }
}
