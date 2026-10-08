import UserNotifications

extension UNAuthorizationStatus {
    var trustMapAccessLabel: String {
        switch self {
        case .authorized:
            return L10n.on
        case .provisional:
            return L10n.quiet
        case .ephemeral:
            return L10n.temporary
        case .denied:
            return L10n.off
        case .notDetermined:
            return L10n.notRequested
        @unknown default:
            return L10n.off
        }
    }

    var trustMapAllowsRemoteNotificationRegistration: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied, .notDetermined:
            return false
        @unknown default:
            return false
        }
    }

    var trustMapShowsOpenNotificationSettings: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral, .denied:
            return true
        case .notDetermined:
            return false
        @unknown default:
            return false
        }
    }
}
