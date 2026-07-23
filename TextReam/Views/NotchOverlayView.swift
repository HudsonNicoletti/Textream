import SwiftUI

/// Composes prompt text, manual scrolling, and resize controls in the floating panel.
struct NotchOverlayView: View {
    @EnvironmentObject var model: TeleprompterModel

    /// Connects the model to `VerticalPromptText`, `ScrollWheelCatcher`, and `WindowResizeGrip`.
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                NotchShape()
                    .fill(.black)
                    .frame(height: 42)

                VerticalPromptText(script: model.script, offset: model.offset, fontSize: model.fontSize, textColor: model.textColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 14)
                    .background(.black, in: UnevenRoundedRectangle(cornerRadii: .init(topLeading: 0, bottomLeading: 18, bottomTrailing: 18, topTrailing: 0), style: .continuous))
                    .padding(.top, -8)
            }
            ScrollWheelCatcher(model: model)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            WindowResizeGrip()
                .frame(width: 20, height: 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .onHover { model.hoverPaused = $0 }
        .accessibilityLabel("Textream teleprompter overlay")
    }
}
