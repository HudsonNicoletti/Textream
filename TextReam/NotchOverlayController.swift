import SwiftUI
import AppKit
import Combine

@MainActor
/// Owns the floating AppKit panel and connects display changes to positioning.
final class NotchOverlayController {
    private let model: TeleprompterModel
    private var window: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    /// Stores shared state and subscribes to display changes.
    init(model: TeleprompterModel) {
        self.model = model
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.position() }
            .store(in: &cancellables)
    }

    /// Creates, positions, and raises the overlay panel.
    func show() {
        if window == nil { makeWindow() }
        position()
        window?.orderFrontRegardless()
    }

    /// Hosts `NotchOverlayView` in a private nonactivating `NSPanel`.
    private func makeWindow() {
        let content = NotchOverlayView().environmentObject(model)
        let hosting = NSHostingView(rootView: content)
        let w = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        w.contentView = hosting
        w.isOpaque = false
        w.backgroundColor = .clear
        w.level = .statusBar
        w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
#if DEBUG
        w.sharingType = .readOnly
#else
        w.sharingType = .none
#endif
        w.hidesOnDeactivate = false
        w.hasShadow = false
        w.minSize = NSSize(width: 220, height: 120)
        w.maxSize = NSSize(width: 340, height: 360)
        window = w
    }

    /// Applies `NotchGeometry` for the main screen to the panel.
    private func position() {
        guard let screen = NSScreen.main, let window else { return }
        let notch = NotchGeometry.for(screen)
        window.setFrame(notch.frame, display: true)
    }
}

struct NotchGeometry {
    let frame: CGRect
    let hasPhysicalNotch: Bool

    /// Derives the overlay frame from public `NSScreen` geometry.
    static func `for`(_ screen: NSScreen) -> NotchGeometry {
        let f = screen.frame
        let topInset = screen.safeAreaInsets.top
        let looksNotched = screen.localizedName.contains("Built-in") && topInset >= 24 && f.width >= 1400

        let notchWidth: CGFloat = looksNotched ? 273 : 312
        let notchHeight: CGFloat = looksNotched ? max(32, topInset + 2) : 42
        let width = notchWidth
        let height = notchHeight + 133
        let x = f.midX - width / 2
        let y = f.maxY - height
        return NotchGeometry(frame: CGRect(x: x, y: y, width: width, height: height), hasPhysicalNotch: looksNotched)
    }
}
