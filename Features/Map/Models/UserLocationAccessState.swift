import Foundation

enum UserLocationAccessState: Equatable {
    case idle
    case requestingPermission
    case locating
    case ready
    case denied
    case restricted
    case failed(String)

    var message: String? {
        switch self {
        case .idle, .ready:
            return nil
        case .requestingPermission:
            return "TrustMap is requesting access to your location to center the map around you."
        case .locating:
            return "Finding your current location."
        case .denied:
            return "Location access is off. Enable it in Settings to center the map on your current position."
        case .restricted:
            return "Location access is restricted on this device."
        case .failed(let message):
            return message
        }
    }

    var showsSettingsAction: Bool {
        switch self {
        case .denied, .restricted:
            return true
        default:
            return false
        }
    }
}
