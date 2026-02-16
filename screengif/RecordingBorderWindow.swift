import Cocoa

@MainActor
final class RecordingBorderWindow: NSWindow {

    private let borderView: BorderView

    init(region: CGRect) {
        let padding: CGFloat = 3
        let frame = region.insetBy(dx: -padding, dy: -padding)

        borderView = BorderView(frame: NSRect(origin: .zero, size: frame.size))

        super.init(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        self.level = .statusBar
        self.isOpaque = false
        self.backgroundColor = .clear
        self.ignoresMouseEvents = true
        self.hasShadow = false
        self.contentView = borderView

        self.setFrame(frame, display: true)
    }
}

@MainActor
private final class BorderView: NSView {

    private var phase: CGFloat = 0
    private var animTimer: Timer?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            animTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self else { return }
                self.phase += 4
                self.needsDisplay = true
            }
        } else {
            animTimer?.invalidate()
            animTimer = nil
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 1.5, dy: 1.5)

        // Red border
        let path = NSBezierPath(rect: rect)
        path.lineWidth = 3
        NSColor.systemRed.withAlphaComponent(0.9).setStroke()
        path.stroke()

        // Animated dashed white inner line
        let innerPath = NSBezierPath(rect: rect.insetBy(dx: 2, dy: 2))
        innerPath.lineWidth = 1
        innerPath.setLineDash([8, 6], count: 2, phase: phase)
        NSColor.white.withAlphaComponent(0.6).setStroke()
        innerPath.stroke()

        // Red dot indicator top-left
        let dotSize: CGFloat = 8
        let dot = NSRect(x: 6, y: bounds.height - dotSize - 6, width: dotSize, height: dotSize)
        NSColor.systemRed.setFill()
        NSBezierPath(ovalIn: dot).fill()
    }

    deinit {
        animTimer?.invalidate()
    }
}
