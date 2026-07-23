import SwiftUI

/// Renders the model script at its animated overlay offset.
struct VerticalPromptText: View {
    let script: String
    let offset: CGFloat
    let fontSize: Double
    let textColor: Color

    /// Connects script appearance and offset to a masked noninteractive scroll view.
    var body: some View {
        GeometryReader { proxy in
            ScrollView(.vertical) {
                Text(script.isEmpty ? "Textream" : script)
                    .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .frame(width: proxy.size.width)
                    .offset(y: -offset)
                    .padding(.vertical, 16)
            }
            .scrollDisabled(true)
            .scrollIndicators(.hidden)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .mask(LinearGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.12),
                .init(color: .black, location: 0.88),
                .init(color: .clear, location: 1)
            ], startPoint: .top, endPoint: .bottom))
                .foregroundStyle(textColor)
                .animation(.linear(duration: 0.08), value: offset)
        }
    }
}
