import Cocoa

@MainActor
final class RecordingBackdropWindow: NSWindow {

    init(screen: NSScreen, clearRect: CGRect) {
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        self.level = .screenSaver
        self.isOpaque = false
        self.backgroundColor = .clear
        self.ignoresMouseEvents = true
        self.hasShadow = false

        let view = BackdropView(
            frame: NSRect(origin: .zero, size: screen.frame.size),
            screenOrigin: screen.frame.origin,
            clearRect: clearRect
        )
        self.contentView = view
        self.setFrame(screen.frame, display: true)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
private final class BackdropView: NSView {

    private let screenOrigin: CGPoint
    private let clearRect: CGRect

    init(frame: NSRect, screenOrigin: CGPoint, clearRect: CGRect) {
        self.screenOrigin = screenOrigin
        self.clearRect = clearRect
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.4).setFill()
        bounds.fill()

        // Convert the clear rect from screen coordinates to view-local coordinates
        let localRect = CGRect(
            x: clearRect.origin.x - screenOrigin.x,
            y: clearRect.origin.y - screenOrigin.y,
            width: clearRect.width,
            height: clearRect.height
        )

        NSColor.clear.setFill()
        localRect.fill(using: .copy)
    }
}
