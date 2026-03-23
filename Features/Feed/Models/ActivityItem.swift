import Foundation
import SwiftData

@Model
final class ActivityItem {
    var id: UUID
    var actorUserId: UUID
    var type: ActivityItemType
    var referenceId: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        actorUserId: UUID,
        type: ActivityItemType,
        referenceId: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.actorUserId = actorUserId
        self.type = type
        self.referenceId = referenceId
        self.createdAt = createdAt
    }
}
