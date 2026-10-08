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
            return L10n.accepted
        case .cancelled:
            return L10n.canceled
        case .pending:
            return L10n.pending
        case .rejected:
            return L10n.rejected
        }
    }
}
