import Foundation

enum PlaceSourceType: String, Codable, CaseIterable, Identifiable {
    case appleMaps
    case manual

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .appleMaps:
            return "Apple Maps"
        case .manual:
            return "Manual"
        }
    }
}
