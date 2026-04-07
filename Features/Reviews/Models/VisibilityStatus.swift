import Foundation

enum VisibilityStatus: String, Codable, CaseIterable, Identifiable {
    case friendsOnly = "Friends"
    case onlyMe = "Private"
    case `public` = "Public"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .friendsOnly:
            return "Friends Only"
        case .onlyMe:
            return "Only Me"
        case .public:
            return "Public"
        }
    }
}
