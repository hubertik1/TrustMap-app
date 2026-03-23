import Foundation

enum VisibilityStatus: String, Codable, CaseIterable, Identifiable {
    case friendsOnly
    case onlyMe

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .friendsOnly:
            return "Friends Only"
        case .onlyMe:
            return "Only Me"
        }
    }
}
