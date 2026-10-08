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
            return L10n.trustmapIsRequestingAccessToYourLocationToCenterTheMapAroundYou
        case .locating:
            return L10n.findingYourCurrentLocation
        case .denied:
            return L10n.locationAccessIsOffEnableItInSettingsToCenterTheMapOnYourCurrentPosition
        case .restricted:
            return L10n.locationAccessIsRestrictedOnThisDevice
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
