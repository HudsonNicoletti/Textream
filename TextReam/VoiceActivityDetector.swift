import AVFoundation

/// Converts microphone buffers into speaking state for `TeleprompterModel`.
final class VoiceActivityDetector: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private var silenceFrames = 0
    private var thresholdDB = -42.0
    private var lastSpeaking = false

    /// Installs the AVAudioEngine tap and sends status and speech changes to the model.
    func start(
        thresholdDB: Double,
        status: @escaping @MainActor @Sendable (String) -> Void,
        speech: @escaping @MainActor @Sendable (Bool) -> Void
    ) {
        self.thresholdDB = thresholdDB
        guard !engine.isRunning else { return }

        guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else {
            Task { @MainActor in status("Microphone permission needed") }
            return
        }

        do {
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.removeTap(onBus: 0)
            try input.__installTap(onBus: 0, bufferSize: 1024, format: format, error: (), block: { [weak self] buffer, _ in
                self?.process(buffer, speech: speech)
            })
            engine.prepare()
            try engine.start()
            Task { @MainActor in status("Listening") }
        } catch {
            let message = "Mic error: \(error.localizedDescription)"
            Task { @MainActor in status(message) }
        }
    }

    /// Removes the input tap and stops the engine when playback pauses.
    func stop() {
        guard engine.isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        lastSpeaking = false
    }

    /// Calculates RMS loudness and forwards threshold changes to `setSpeaking`.
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

    /// Deduplicates speech changes before updating the model on the main actor.
    private func setSpeaking(_ value: Bool, speech: @escaping @MainActor @Sendable (Bool) -> Void) {
        guard value != lastSpeaking else { return }
        lastSpeaking = value
        Task { @MainActor in speech(value) }
    }
}
