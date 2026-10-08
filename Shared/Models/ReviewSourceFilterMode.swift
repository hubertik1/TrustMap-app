import Foundation

enum ReviewSourceFilterMode: String, Codable, CaseIterable, Identifiable {
    case mineOnly
    case friendsOnly
    case mineAndFriends

    static var allCases: [ReviewSourceFilterMode] {
        [.mineAndFriends, .mineOnly, .friendsOnly]
    }

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mineOnly:
            return L10n.mineOnly
        case .friendsOnly:
            return L10n.friendsOnly
        case .mineAndFriends:
            return L10n.mineAndFriends
        }
    }
}
