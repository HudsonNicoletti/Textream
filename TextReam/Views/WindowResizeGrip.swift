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
    private var hoverTrackingArea: NSTrackingArea?
    private lazy var resizeCursor = NSCursor(image: Self.resizeCursorImage(), hotSpot: CGPoint(x: 8, y: 8))

    /// Tracks hover even though the overlay is a nonactivating panel.
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea { removeTrackingArea(hoverTrackingArea) }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        hoverTrackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        resizeCursor.set()
    }

    override func mouseExited(with event: NSEvent) {
        guard NSEvent.pressedMouseButtons == 0 else { return }
        NSCursor.arrow.set()
    }

    /// Captures frame and pointer origins at drag start.
    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        resizeCursor.push()
        startFrame = window.frame
        startMouse = NSEvent.mouseLocation
    }

    /// Restores the normal cursor after resizing ends.
    override func mouseUp(with event: NSEvent) {
        NSCursor.pop()
        let pointer = convert(event.locationInWindow, from: nil)
        bounds.contains(pointer) ? resizeCursor.set() : NSCursor.arrow.set()
    }

    /// Resizes around center within limits set by the overlay controller.
    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        resizeCursor.set()
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
