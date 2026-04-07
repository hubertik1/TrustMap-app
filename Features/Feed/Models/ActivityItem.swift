import Foundation

struct ActivityItem: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let actorUserId: UUID
    let type: ActivityItemType
    let referenceId: String
    let createdAt: Date

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
