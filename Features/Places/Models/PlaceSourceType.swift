import Foundation

enum PlaceSourceType: String, Codable, CaseIterable, Identifiable {
    case providerVenue = "ProviderVenue"
    case customPin = "CustomPin"
    case approvedPublic = "ApprovedPublic"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .providerVenue:
            return "Provider Venue"
        case .customPin:
            return "Custom Pin"
        case .approvedPublic:
            return "Approved Public"
        }
    }
}
