import SwiftUI
import AppKit

/// Bridges `NSVisualEffectView` into the control window background.
struct VisualEffect: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    /// Creates the AppKit material view used behind `ControlView`.
    func makeNSView(context: Context) -> WindowVisualEffectView {
        let view = WindowVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    /// Synchronizes AppKit material settings with SwiftUI inputs.
    func updateNSView(_ view: WindowVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
        view.updateWindowBackground()
    }
}

/// Extends the window background behind native traffic lights without creating a separate title bar.
final class WindowVisualEffectView: NSVisualEffectView {
    private weak var windowBackgroundView: NSVisualEffectView?

    /// Configures the hosting window when SwiftUI attaches this background view.
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        window.styleMask.insert(.fullSizeContentView)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.isMovableByWindowBackground = true
        guard let frameView = window.contentView?.superview, windowBackgroundView == nil else { return }
        let background = NSVisualEffectView(frame: frameView.bounds)
        background.autoresizingMask = [.width, .height]
        background.material = material
        background.blendingMode = blendingMode
        background.state = .active
        frameView.addSubview(background, positioned: .below, relativeTo: nil)
        windowBackgroundView = background
    }

    /// Keeps the frame-wide material synchronized with the SwiftUI background.
    func updateWindowBackground() {
        windowBackgroundView?.material = material
        windowBackgroundView?.blendingMode = blendingMode
    }
}
