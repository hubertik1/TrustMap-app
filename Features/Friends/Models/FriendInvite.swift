import Foundation

struct FriendInvite: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let sender: UserSummary
    let receiver: UserSummary
    let status: FriendInviteStatus
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case createdAt
        case id
        case receiver = "receiver"
        case sender = "sender"
        case status
    }

    init(
        id: UUID = UUID(),
        sender: UserSummary,
        receiver: UserSummary,
        status: FriendInviteStatus = .pending,
        createdAt: Date = .now
    ) {
        self.id = id
        self.sender = sender
        self.receiver = receiver
        self.status = status
        self.createdAt = createdAt
    }

    var inviterUserId: UUID {
        sender.id
    }

    var inviteeUserId: UUID {
        receiver.id
    }
}
