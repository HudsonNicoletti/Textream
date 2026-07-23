import SwiftUI
import AppKit

/// Bridges AppKit scroll events into model offset changes.
struct ScrollWheelCatcher: NSViewRepresentable {
    let model: TeleprompterModel

    /// Creates the AppKit view and connects it to shared state.
    func makeNSView(context: Context) -> ScrollWheelView {
        let view = ScrollWheelView()
        view.model = model
        return view
    }

    /// Refreshes the model reference when SwiftUI updates.
    func updateNSView(_ view: ScrollWheelView, context: Context) {
        view.model = model
    }
}

final class ScrollWheelView: NSView {
    weak var model: TeleprompterModel?

    /// Sends trackpad or wheel movement to `TeleprompterModel.nudge`.
    override func scrollWheel(with event: NSEvent) {
        Task { @MainActor in model?.nudge(CGFloat(event.scrollingDeltaY)) }
    }
}
