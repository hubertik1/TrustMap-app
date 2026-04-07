import Foundation

enum FriendInviteStatus: String, Codable, CaseIterable, Identifiable {
    case accepted = "Accepted"
    case cancelled = "Cancelled"
    case pending = "Pending"
    case rejected = "Rejected"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .accepted:
            return "Accepted"
        case .cancelled:
            return "Canceled"
        case .pending:
            return "Pending"
        case .rejected:
            return "Rejected"
        }
    }
}
