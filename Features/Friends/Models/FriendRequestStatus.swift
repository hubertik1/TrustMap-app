import Foundation

enum FriendRequestStatus: String, Codable, CaseIterable, Identifiable {
    case pending
    case accepted
    case rejected

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pending:
            return "Pending"
        case .accepted:
            return "Accepted"
        case .rejected:
            return "Rejected"
        }
    }
}
