import SwiftUI
import AppKit
import AVFoundation
import Combine

@MainActor
/// Owns teleprompter state and connects controls, audio detection, and overlay rendering.
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
    @Published private(set) var microphonePermission = AVCaptureDevice.authorizationStatus(for: .audio)

    private let vad = VoiceActivityDetector()
    private var timer: Timer?
    private var lastTick = Date()

    /// Restores persisted script and appearance settings used by both app views.
    init() {
        script = UserDefaults.standard.string(forKey: Self.scriptKey) ?? Self.defaultScript
        let savedFontSize = UserDefaults.standard.double(forKey: Self.fontSizeKey)
        if savedFontSize > 0 { fontSize = savedFontSize }
        textColor = Self.loadTextColor()
    }

    /// Tells `VerticalPromptText` when playback, speech, and hover state permit scrolling.
    var shouldScroll: Bool { isPlaying && isSpeaking && !hoverPaused }

    /// Maps AVFoundation authorization into the action displayed by `ControlView`.
    var permissionAction: MicrophonePermissionAction {
        microphonePermissionAction(for: microphonePermission)
    }

    /// Routes Play/Pause to `start()` or the shared cleanup path.
    func togglePlayback() {
        isPlaying.toggle()
        if isPlaying { start() } else { stopScrollOnly() }
    }

    /// Starts the timer and `VoiceActivityDetector`, requesting permission first when needed.
    func start() {
        guard microphonePermission == .authorized else {
            isPlaying = false
            enableMicrophone()
            return
        }
        isPlaying = true
        lastTick = Date()
        startTimer()
        vad.start(
            thresholdDB: sensitivity,
            status: { [weak self] message in self?.micStatus = message },
            speech: { [weak self] speaking in self?.isSpeaking = speaking }
        )
    }

    /// Stops playback through the same cleanup path used by the controls.
    func pause() {
        isPlaying = false
        stopScrollOnly()
    }

    /// Resets the offset consumed by `VerticalPromptText`.
    func reset() {
        offset = 0
    }

    /// Applies keyboard or trackpad movement to the overlay offset.
    func nudge(_ amount: CGFloat) {
        offset = max(0, offset + amount)
    }

    /// Checks launch authorization and connects an undetermined state to the native macOS microphone prompt.
    func requestMicrophonePermissionOnLaunch() {
        refreshMicrophonePermission()
        guard permissionAction == .request else { return }
        enableMicrophone()
    }

    /// Reads AVFoundation authorization on launch and app activation.
    func refreshMicrophonePermission() {
        microphonePermission = AVCaptureDevice.authorizationStatus(for: .audio)
        guard !isPlaying else { return }
        micStatus = microphonePermission == .authorized ? "Microphone ready" : "Microphone permission needed"
    }

    /// Connects permission UI to the native prompt or macOS Privacy settings.
    func enableMicrophone() {
        switch permissionAction {
        case .request:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] _ in
                Task { @MainActor in self?.refreshMicrophonePermission() }
            }
        case .openSettings:
            guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") else { return }
            NSWorkspace.shared.open(url)
        case .unavailable, .ready:
            break
        }
    }

    /// Restores RGB values from `UserDefaults` for both views.
    private static func loadTextColor() -> Color {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: textColorRedKey) != nil else { return .white }
        return Color(
            red: defaults.double(forKey: textColorRedKey),
            green: defaults.double(forKey: textColorGreenKey),
            blue: defaults.double(forKey: textColorBlueKey)
        )
    }

    /// Persists the selected SwiftUI color as RGB values in `UserDefaults`.
    private func saveTextColor() {
        guard let color = NSColor(textColor).usingColorSpace(.sRGB) else { return }
        let defaults = UserDefaults.standard
        defaults.set(color.redComponent, forKey: Self.textColorRedKey)
        defaults.set(color.greenComponent, forKey: Self.textColorGreenKey)
        defaults.set(color.blueComponent, forKey: Self.textColorBlueKey)
    }

    /// Stops the timer and voice detector while preserving script and offset.
    private func stopScrollOnly() {
        timer?.invalidate()
        timer = nil
        vad.stop()
        micStatus = "Paused"
    }

    /// Creates the 60 Hz timer that drives `tick()`.
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    /// Advances the offset from elapsed time when `shouldScroll` is true.
    private func tick() {
        let now = Date()
        let dt = now.timeIntervalSince(lastTick)
        lastTick = now
        guard shouldScroll else { return }
        offset += CGFloat(speed * dt)
    }
}
