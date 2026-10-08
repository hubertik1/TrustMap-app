import Foundation

enum PeopleFilterMode: String, Codable, CaseIterable, Identifiable {
    case allVisible
    case includeSelected
    case excludeSelected

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .allVisible:
            return L10n.allVisible
        case .includeSelected:
            return L10n.includeSelected
        case .excludeSelected:
            return L10n.excludeSelected
        }
    }
}
