import Foundation

enum ReviewSourceFilterMode: String, Codable, CaseIterable, Identifiable {
    case mineOnly
    case friendsOnly
    case mineAndFriends

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mineOnly:
            return "Mine Only"
        case .friendsOnly:
            return "Friends Only"
        case .mineAndFriends:
            return "Mine and Friends"
        }
    }
}
