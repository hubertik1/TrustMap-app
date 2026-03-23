import Foundation

enum PeopleFilterMode: String, Codable, CaseIterable, Identifiable {
    case allVisible
    case includeSelected
    case excludeSelected

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .allVisible:
            return "All Visible"
        case .includeSelected:
            return "Include Selected"
        case .excludeSelected:
            return "Exclude Selected"
        }
    }
}
