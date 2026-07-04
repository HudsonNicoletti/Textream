import SwiftUI
import AppKit
import AVFoundation
import Combine

@main
struct TextreamApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = TeleprompterModel()

    var body: some Scene {
        WindowGroup("Textream") {
            ControlView()
                .environmentObject(model)
                .frame(minWidth: 520, minHeight: 560)
                .onAppear { appDelegate.bind(model) }
        }
        .windowResizability(.contentSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var overlay: NotchOverlayController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }

    @MainActor
    func bind(_ model: TeleprompterModel) {
        if overlay == nil { overlay = NotchOverlayController(model: model) }
        overlay?.show()
    }
}

@MainActor
final class TeleprompterModel: ObservableObject {
    @Published var script = "Paste your script here.\n\nTextream scrolls while you speak and pauses when you stop."
    @Published var isPlaying = false
    @Published var isSpeaking = false
    @Published var speed: Double = 42
    @Published var offset: CGFloat = 0
    @Published var sensitivity: Double = -42
    @Published var overlayOpacity: Double = 0.96
    @Published var micStatus = "Microphone idle"

    private let vad = VoiceActivityDetector()
    private var timer: Timer?
    private var lastTick = Date()

    var shouldScroll: Bool { isPlaying && isSpeaking }

    func togglePlayback() {
        isPlaying.toggle()
        if isPlaying { start() } else { stopScrollOnly() }
    }

    func start() {
        isPlaying = true
        lastTick = Date()
        startTimer()
        vad.start(
            thresholdDB: sensitivity,
            status: { [weak self] message in self?.micStatus = message },
            speech: { [weak self] speaking in self?.isSpeaking = speaking }
        )
    }

    func pause() {
        isPlaying = false
        stopScrollOnly()
    }

    func reset() {
        offset = 0
    }

    private func stopScrollOnly() {
        timer?.invalidate()
        timer = nil
        vad.stop()
        micStatus = "Paused"
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        let now = Date()
        let dt = now.timeIntervalSince(lastTick)
        lastTick = now
        guard shouldScroll else { return }
        offset += CGFloat(speed * dt)
    }
}

final class VoiceActivityDetector: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private var silenceFrames = 0
    private var thresholdDB = -42.0
    private var lastSpeaking = false

    func start(
        thresholdDB: Double,
        status: @escaping @MainActor @Sendable (String) -> Void,
        speech: @escaping @MainActor @Sendable (Bool) -> Void
    ) {
        self.thresholdDB = thresholdDB
        guard !engine.isRunning else { return }

        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            guard let self else { return }
            guard granted else {
                Task { @MainActor in status("Microphone denied in System Settings") }
                return
            }

            do {
                let input = self.engine.inputNode
                let format = input.outputFormat(forBus: 0)
                input.removeTap(onBus: 0)
                input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                    self?.process(buffer, speech: speech)
                }
                self.engine.prepare()
                try self.engine.start()
                Task { @MainActor in status("Listening") }
            } catch {
                let message = "Mic error: \(error.localizedDescription)"
                Task { @MainActor in status(message) }
            }
        }
    }

    func stop() {
        guard engine.isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        lastSpeaking = false
    }

    private func process(_ buffer: AVAudioPCMBuffer, speech: @escaping @MainActor @Sendable (Bool) -> Void) {
        guard let channel = buffer.floatChannelData?[0] else { return }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return }

        var sum: Float = 0
        for i in 0..<count { sum += channel[i] * channel[i] }
        let rms = sqrt(sum / Float(count))
        let db = 20 * log10(max(rms, 0.000_001))
        let speakingNow = Double(db) > thresholdDB

        if speakingNow {
            silenceFrames = 0
            setSpeaking(true, speech: speech)
        } else {
            silenceFrames += 1
            // ponytail: small hangover avoids jitter; tune if you need broadcast-grade VAD.
            if silenceFrames > 18 { setSpeaking(false, speech: speech) }
        }
    }

    private func setSpeaking(_ value: Bool, speech: @escaping @MainActor @Sendable (Bool) -> Void) {
        guard value != lastSpeaking else { return }
        lastSpeaking = value
        Task { @MainActor in speech(value) }
    }
}

@MainActor
final class NotchOverlayController {
    private let model: TeleprompterModel
    private var window: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    init(model: TeleprompterModel) {
        self.model = model
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.position() }
            .store(in: &cancellables)
    }

    func show() {
        if window == nil { makeWindow() }
        position()
        window?.orderFrontRegardless()
    }

    private func makeWindow() {
        let content = NotchOverlayView().environmentObject(model)
        let hosting = NSHostingView(rootView: content)
        let w = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        w.contentView = hosting
        w.isOpaque = false
        w.backgroundColor = .clear
        w.level = .statusBar
        w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        w.hidesOnDeactivate = false
        w.hasShadow = false
        window = w
    }

    private func position() {
        guard let screen = NSScreen.main, let window else { return }
        let notch = NotchGeometry.for(screen)
        window.setFrame(notch.frame, display: true)
    }
}

struct NotchGeometry {
    let frame: CGRect
    let hasPhysicalNotch: Bool

    static func `for`(_ screen: NSScreen) -> NotchGeometry {
        let f = screen.frame
        let topInset = screen.safeAreaInsets.top
        let looksNotched = screen.localizedName.contains("Built-in") && topInset >= 24 && f.width >= 1400

        let notchWidth: CGFloat = looksNotched ? 210 : 240
        let notchHeight: CGFloat = looksNotched ? max(32, topInset + 2) : 42
        let width = notchWidth
        let height = notchHeight + 133
        let x = f.midX - width / 2
        let y = f.maxY - height
        return NotchGeometry(frame: CGRect(x: x, y: y, width: width, height: height), hasPhysicalNotch: looksNotched)
    }
}

struct NotchOverlayView: View {
    @EnvironmentObject var model: TeleprompterModel

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                NotchShape()
                    .fill(.black)
                    .frame(height: 42)

                VerticalPromptText(script: model.script, offset: model.offset)
                    .frame(maxWidth: .infinity, maxHeight: 133)
                    .padding(.horizontal, 14)
                    .background(.black, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.top, -8)
            }
        }
        .accessibilityLabel("Textream teleprompter overlay")
    }
}

struct VerticalPromptText: View {
    let script: String
    let offset: CGFloat

    var body: some View {
        GeometryReader { proxy in
            ScrollView(.vertical) {
                Text(script.isEmpty ? "Textream" : script)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
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
                .foregroundStyle(.white)
                .animation(.linear(duration: 0.08), value: offset)
        }
    }
}

struct NotchShape: Shape {
    func path(in rect: CGRect) -> Path {
        let r = min(rect.height * 0.42, 22)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r), control: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

struct ControlView: View {
    @EnvironmentObject var model: TeleprompterModel

    var body: some View {
        VStack(spacing: 18) {
            header
            TextEditor(text: $model.script)
                .font(.system(.body, design: .rounded))
                .scrollContentBackground(.hidden)
                .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.10)))
                .frame(minHeight: 260)
                .accessibilityLabel("Teleprompter script")
            controls
            status
        }
        .padding(24)
        .background(VisualEffect(material: .hudWindow, blendingMode: .behindWindow))
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Textream")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                Text("Speak to scroll. Stop to pause.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Circle()
                .fill(model.isSpeaking ? .green : .orange)
                .frame(width: 12, height: 12)
                .accessibilityLabel(model.isSpeaking ? "Speaking" : "Silent")
        }
    }

    private var controls: some View {
        VStack(spacing: 14) {
            HStack {
                Button(model.isPlaying ? "Pause" : "Play") { model.togglePlayback() }
                    .keyboardShortcut(.space, modifiers: [])
                    .buttonStyle(.borderedProminent)
                Button("Reset") { model.reset() }
                Spacer()
                Text("\(Int(model.speed)) px/s")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Speed")
                Slider(value: $model.speed, in: 10...160)
            }
            HStack {
                Text("Mic sensitivity")
                Slider(value: $model.sensitivity, in: -65 ... -25)
            }
        }
    }

    private var status: some View {
        HStack {
            Text(model.micStatus)
            Spacer()
            Text(model.shouldScroll ? "Scrolling" : "Paused")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

struct VisualEffect: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
    }
}
