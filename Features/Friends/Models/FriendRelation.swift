import Foundation
import SwiftData

@Model
final class FriendRelation {
    var id: UUID
    var ownerUserId: UUID
    var targetUserId: UUID
    var status: FriendRequestStatus
    var createdAt: Date

    init(
        id: UUID = UUID(),
        ownerUserId: UUID,
        targetUserId: UUID,
        status: FriendRequestStatus,
        createdAt: Date = .now
    ) {
        self.id = id
        self.ownerUserId = ownerUserId
        self.targetUserId = targetUserId
        self.status = status
        self.createdAt = createdAt
    }
}
