import Foundation

enum PlaceSourceType: String, Codable, CaseIterable, Identifiable {
    case providerVenue = "ProviderVenue"
    case customPin = "CustomPin"
    case approvedPublic = "ApprovedPublic"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .providerVenue:
            return L10n.providerVenue
        case .customPin:
            return L10n.customPin
        case .approvedPublic:
            return L10n.approvedPublic
        }
    }
}
