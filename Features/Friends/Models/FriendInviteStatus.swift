import Foundation

enum FriendInviteStatus: String, Codable, CaseIterable, Identifiable {
    case pending
    case accepted
    case declined
    case revoked
    case expired

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pending:
            return "Pending"
        case .accepted:
            return "Accepted"
        case .declined:
            return "Declined"
        case .revoked:
            return "Canceled"
        case .expired:
            return "Expired"
        }
    }
}
