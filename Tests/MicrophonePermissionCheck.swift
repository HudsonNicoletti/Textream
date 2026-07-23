import AVFoundation

@main
struct MicrophonePermissionCheck {
    /// Verifies every AVFoundation status maps to the action expected by the permission UI.
    static func main() {
        assert(microphonePermissionAction(for: .notDetermined) == .request)
        assert(microphonePermissionAction(for: .denied) == .openSettings)
        assert(microphonePermissionAction(for: .restricted) == .unavailable)
        assert(microphonePermissionAction(for: .authorized) == .ready)
    }
}
