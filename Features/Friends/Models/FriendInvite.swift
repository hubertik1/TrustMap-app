import Foundation
import SwiftData

@Model
final class FriendInvite {
    var id: UUID
    var token: String
    var inviterUserId: UUID
    var inviteeUserId: UUID?
    var status: FriendInviteStatus
    var createdAt: Date
    var expiresAt: Date?
    var respondedAt: Date?

    init(
        id: UUID = UUID(),
        token: String,
        inviterUserId: UUID,
        inviteeUserId: UUID? = nil,
        status: FriendInviteStatus = .pending,
        createdAt: Date = .now,
        expiresAt: Date? = nil,
        respondedAt: Date? = nil
    ) {
        self.id = id
        self.token = token
        self.inviterUserId = inviterUserId
        self.inviteeUserId = inviteeUserId
        self.status = status
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.respondedAt = respondedAt
    }

    var isExpired: Bool {
        guard let expiresAt else {
            return status == .expired
        }

        return status == .expired || expiresAt < .now
    }
}
