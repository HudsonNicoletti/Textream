import AVFoundation

/// Describes the next permission step `TeleprompterModel` exposes to `ControlView`.
enum MicrophonePermissionAction: Equatable {
    case request
    case openSettings
    case unavailable
    case ready
}

/// Maps AVFoundation authorization into the UI action consumed by `TeleprompterModel`.
func microphonePermissionAction(for status: AVAuthorizationStatus) -> MicrophonePermissionAction {
    switch status {
    case .notDetermined: .request
    case .denied: .openSettings
    case .restricted: .unavailable
    case .authorized: .ready
    @unknown default: .unavailable
    }
}
