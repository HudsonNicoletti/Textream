import SwiftUI
import AppKit

/// Exposes an AppKit drag handle for the floating overlay panel.
struct WindowResizeGrip: NSViewRepresentable {
    /// Creates the `ResizeGripView` hosted by `NotchOverlayView`.
    func makeNSView(context: Context) -> ResizeGripView { ResizeGripView() }
    /// Requires no updates because the grip reads its panel directly.
    func updateNSView(_ view: ResizeGripView, context: Context) {}
}

final class ResizeGripView: NSView {
    private var startFrame = CGRect.zero
    private var startMouse = CGPoint.zero
    private lazy var resizeCursor = NSCursor(image: Self.resizeCursorImage(), hotSpot: CGPoint(x: 8, y: 8))

    /// Refreshes cursor regions after SwiftUI attaches the grip.
    override func viewDidMoveToWindow() {
        window?.invalidateCursorRects(for: self)
    }

    /// Registers the custom resize cursor over the grip.
    override func resetCursorRects() {
        addCursorRect(bounds, cursor: resizeCursor)
    }

    /// Captures frame and pointer origins at drag start.
    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        startFrame = window.frame
        startMouse = NSEvent.mouseLocation
    }

    /// Resizes around center within limits set by the overlay controller.
    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        let mouse = NSEvent.mouseLocation
        let dx = mouse.x - startMouse.x
        let dy = mouse.y - startMouse.y
        let centerX = startFrame.midX
        let width = min(max(startFrame.width + (dx * 2), window.minSize.width), window.maxSize.width)
        let height = min(max(startFrame.height - dy, window.minSize.height), window.maxSize.height)
        window.setFrame(CGRect(x: centerX - (width / 2), y: startFrame.maxY - height, width: width, height: height), display: true)
    }

    /// Draws the cursor used by `resetCursorRects()`.
    private static func resizeCursorImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 16, height: 16))
        image.lockFocus()
        NSColor.white.setStroke()
        let path = NSBezierPath()
        path.lineWidth = 1.8
        path.move(to: NSPoint(x: 3, y: 13))
        path.line(to: NSPoint(x: 13, y: 3))
        path.move(to: NSPoint(x: 3, y: 9))
        path.line(to: NSPoint(x: 3, y: 13))
        path.line(to: NSPoint(x: 7, y: 13))
        path.move(to: NSPoint(x: 9, y: 3))
        path.line(to: NSPoint(x: 13, y: 3))
        path.line(to: NSPoint(x: 13, y: 7))
        path.stroke()
        image.unlockFocus()
        return image
    }
}
