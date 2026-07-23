import SwiftUI
import AppKit

/// Presents script editing, settings, status, and playback actions.
struct ControlView: View {
    @EnvironmentObject var model: TeleprompterModel

    /// Connects all control sections to `TeleprompterModel`.
    var body: some View {
        VStack(spacing: 18) {
            appIcon
            TextEditor(text: $model.script)
                .font(.system(.body, design: .rounded))
                .scrollContentBackground(.hidden)
                .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.10)))
                .frame(minHeight: 260)
                .accessibilityLabel("Teleprompter script")
            controls
            status
            bottomActions
        }
        .padding(24)
        .background(VisualEffect(material: .hudWindow, blendingMode: .behindWindow).ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    /// Shows the bundle icon and connects its badge to speaking state.
    private var appIcon: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 76, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: .black.opacity(0.28), radius: 14, y: 8)
                .accessibilityLabel("Textream")
            Circle()
                .fill(model.isSpeaking ? .green : .orange)
                .frame(width: 12, height: 12)
                .overlay(Circle().stroke(.black.opacity(0.8), lineWidth: 2))
                .accessibilityLabel(model.isSpeaking ? "Speaking" : "Silent")
        }
    }


    /// Binds appearance and sensitivity controls to model settings.
    private var controls: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Speed")
                Slider(value: $model.speed, in: 10...160)
                Text("\(Int(model.speed)) px/s")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Font size")
                Slider(value: $model.fontSize, in: 12...36, step: 1)
                Text("\(Int(model.fontSize))")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            ColorPicker("Text color", selection: $model.textColor, supportsOpacity: false)
            HStack {
                Text("Mic sensitivity")
                Slider(value: $model.sensitivity, in: -65 ... -25)
            }
        }
    }

    /// Displays microphone and scrolling state from the model.
    private var status: some View {
        HStack {
            Text(model.micStatus)
            Spacer()
            Text(model.hoverPaused ? "Hover paused" : (model.shouldScroll ? "Scrolling" : "Paused"))
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    /// Connects Play, Reset, and Quit to model and AppKit actions.
    private var bottomActions: some View {
        HStack(spacing: 22) {
            glyphButton(model.isPlaying ? "Pause" : "Play", systemImage: model.isPlaying ? "pause.fill" : "play.fill") {
                model.togglePlayback()
            }
            .keyboardShortcut(.space, modifiers: [])

            glyphButton("Reset", systemImage: "arrow.counterclockwise") {
                model.reset()
            }

            glyphButton("Quit", systemImage: "power") {
                NSApp.terminate(nil)
            }
        }
        .padding(.top, 2)
        .frame(maxWidth: .infinity)
    }

    /// Applies shared visuals and accessibility to action buttons.
    private func glyphButton(_ label: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .frame(width: 48, height: 44)
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.white.opacity(0.12)))
        .foregroundStyle(.white)
        .accessibilityLabel(label)
    }
}
