import UserNotifications

extension UNAuthorizationStatus {
    var trustMapAccessLabel: String {
        switch self {
        case .authorized:
            return "On"
        case .provisional:
            return "Quiet"
        case .ephemeral:
            return "Temporary"
        case .denied:
            return "Off"
        case .notDetermined:
            return "Not Requested"
        @unknown default:
            return "Off"
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
