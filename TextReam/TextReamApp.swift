//
//  TextReamApp.swift
//  TextReam
//  Created by Hudson Nicoletti on 20/07/26.
//

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
        .commands {
            CommandMenu("Prompter") {
                Button("Back") { model.nudge(-120) }
                    .keyboardShortcut(.upArrow, modifiers: [])
                Button("Forward") { model.nudge(120) }
                    .keyboardShortcut(.downArrow, modifiers: [])
                Button("Reset") { model.reset() }
                    .keyboardShortcut(.leftArrow, modifiers: [.command])
            }
        }
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
    private static let scriptKey = "teleprompter.script"
    private static let fontSizeKey = "teleprompter.fontSize"
    private static let textColorRedKey = "teleprompter.textColor.red"
    private static let textColorGreenKey = "teleprompter.textColor.green"
    private static let textColorBlueKey = "teleprompter.textColor.blue"
    private static let defaultScript = "Paste your script here.\n\nTextream scrolls while you speak and pauses when you stop."

    @Published var script: String {
        didSet { UserDefaults.standard.set(script, forKey: Self.scriptKey) }
    }
    @Published var isPlaying = false
    @Published var isSpeaking = false
    @Published var hoverPaused = false
    @Published var speed: Double = 42
    @Published var fontSize: Double = 17 {
        didSet { UserDefaults.standard.set(fontSize, forKey: Self.fontSizeKey) }
    }
    @Published var textColor = Color.white {
        didSet { saveTextColor() }
    }
    @Published var offset: CGFloat = 0
    @Published var sensitivity: Double = -42
    @Published var overlayOpacity: Double = 0.96
    @Published var micStatus = "Microphone idle"

    private let vad = VoiceActivityDetector()
    private var timer: Timer?
    private var lastTick = Date()

    init() {
        script = UserDefaults.standard.string(forKey: Self.scriptKey) ?? Self.defaultScript
        let savedFontSize = UserDefaults.standard.double(forKey: Self.fontSizeKey)
        if savedFontSize > 0 { fontSize = savedFontSize }
        textColor = Self.loadTextColor()
    }

    var shouldScroll: Bool { isPlaying && isSpeaking && !hoverPaused }

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

    func nudge(_ amount: CGFloat) {
        offset = max(0, offset + amount)
    }

    private static func loadTextColor() -> Color {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: textColorRedKey) != nil else { return .white }
        return Color(
            red: defaults.double(forKey: textColorRedKey),
            green: defaults.double(forKey: textColorGreenKey),
            blue: defaults.double(forKey: textColorBlueKey)
        )
    }

    private func saveTextColor() {
        guard let color = NSColor(textColor).usingColorSpace(.sRGB) else { return }
        let defaults = UserDefaults.standard
        defaults.set(color.redComponent, forKey: Self.textColorRedKey)
        defaults.set(color.greenComponent, forKey: Self.textColorGreenKey)
        defaults.set(color.blueComponent, forKey: Self.textColorBlueKey)
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
        w.sharingType = .none
        w.hidesOnDeactivate = false
        w.hasShadow = false
        w.minSize = NSSize(width: 220, height: 120)
        w.maxSize = NSSize(width: 640, height: 360)
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

        let notchWidth: CGFloat = looksNotched ? 273 : 312
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

struct ScrollWheelCatcher: NSViewRepresentable {
    let model: TeleprompterModel

    func makeNSView(context: Context) -> ScrollWheelView {
        let view = ScrollWheelView()
        view.model = model
        return view
    }

    func updateNSView(_ view: ScrollWheelView, context: Context) {
        view.model = model
    }
}

final class ScrollWheelView: NSView {
    weak var model: TeleprompterModel?

    override func scrollWheel(with event: NSEvent) {
        Task { @MainActor in model?.nudge(CGFloat(event.scrollingDeltaY)) }
    }
}

struct WindowResizeGrip: NSViewRepresentable {
    func makeNSView(context: Context) -> ResizeGripView { ResizeGripView() }
    func updateNSView(_ view: ResizeGripView, context: Context) {}
}

final class ResizeGripView: NSView {
    private var startFrame = CGRect.zero
    private var startMouse = CGPoint.zero
    private lazy var resizeCursor = NSCursor(image: Self.resizeCursorImage(), hotSpot: CGPoint(x: 8, y: 8))

    override func viewDidMoveToWindow() {
        window?.invalidateCursorRects(for: self)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: resizeCursor)
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        startFrame = window.frame
        startMouse = NSEvent.mouseLocation
    }

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

struct VerticalPromptText: View {
    let script: String
    let offset: CGFloat
    let fontSize: Double
    let textColor: Color

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
        .background(VisualEffect(material: .hudWindow, blendingMode: .behindWindow))
        .preferredColorScheme(.dark)
    }

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

    private var status: some View {
        HStack {
            Text(model.micStatus)
            Spacer()
            Text(model.hoverPaused ? "Hover paused" : (model.shouldScroll ? "Scrolling" : "Paused"))
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

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
