import Cocoa

@MainActor
final class RegionSelector {

    private var overlayWindows: [NSWindow] = []
    private var completion: ((CGRect, NSScreen)?) -> Void = { _ in }

    func selectRegion(completion: @escaping ((CGRect, NSScreen)?) -> Void) {
        self.completion = completion

        for screen in NSScreen.screens {
            let window = OverlayWindow(
                screen: screen,
                onSelect: { [weak self] rect in
                    self?.finishSelection(rect: rect, screen: screen)
                },
                onCancel: { [weak self] in
                    self?.cancel()
                }
            )
            overlayWindows.append(window)
            window.makeKeyAndOrderFront(nil)
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    private func finishSelection(rect: CGRect, screen: NSScreen) {
        let result = (rect, screen)
        closeAll()
        completion(result)
    }

    func cancel() {
        closeAll()
        completion(nil)
    }

    private func closeAll() {
        for window in overlayWindows {
            window.orderOut(nil)
        }
        overlayWindows.removeAll()
    }
}

// MARK: - Overlay Window

@MainActor
private final class OverlayWindow: NSWindow {

    private let onSelect: (CGRect) -> Void
    private let onCancel: () -> Void

    init(screen: NSScreen, onSelect: @escaping (CGRect) -> Void, onCancel: @escaping () -> Void) {
        self.onSelect = onSelect
        self.onCancel = onCancel

        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        self.level = .screenSaver
        self.isOpaque = false
        self.backgroundColor = NSColor.black.withAlphaComponent(0.2)
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        self.hasShadow = false

        let overlay = SelectionOverlayView(
            frame: NSRect(origin: .zero, size: screen.frame.size),
            onSelect: onSelect,
            onCancel: onCancel
        )
        self.contentView = overlay
        self.setFrame(screen.frame, display: true)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - Selection Overlay View

@MainActor
private final class SelectionOverlayView: NSView {

    private var dragStart: NSPoint?
    private var dragEnd: NSPoint?
    private let onSelect: (CGRect) -> Void
    private let onCancel: () -> Void

    init(frame: NSRect, onSelect: @escaping (CGRect) -> Void, onCancel: @escaping () -> Void) {
        self.onSelect = onSelect
        self.onCancel = onCancel
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func mouseDown(with event: NSEvent) {
        dragStart = convert(event.locationInWindow, from: nil)
        dragEnd = dragStart
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        dragEnd = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let start = dragStart, let end = dragEnd else { return }

        let rect = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )

        guard rect.width >= 10 && rect.height >= 10 else {
            dragStart = nil
            dragEnd = nil
            needsDisplay = true
            return
        }

        guard let screenFrame = window?.screen?.frame else { return }
        let screenRect = CGRect(
            x: screenFrame.origin.x + rect.origin.x,
            y: screenFrame.origin.y + rect.origin.y,
            width: rect.width,
            height: rect.height
        )

        onSelect(screenRect)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel()
        }
    }

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.3).setFill()
        dirtyRect.fill()

        guard let start = dragStart, let end = dragEnd else { return }

        let selectionRect = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )

        NSColor.clear.setFill()
        selectionRect.fill(using: .copy)
    }
}
