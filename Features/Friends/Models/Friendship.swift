import Foundation
import SwiftData

@Model
final class Friendship {
    var id: UUID
    var userAId: UUID
    var userBId: UUID
    var createdAt: Date

    init(
        id: UUID = UUID(),
        userAId: UUID,
        userBId: UUID,
        createdAt: Date = .now
    ) {
        let orderedPair = Self.orderedPair(userAId, userBId)
        self.id = id
        self.userAId = orderedPair.0
        self.userBId = orderedPair.1
        self.createdAt = createdAt
    }

    func otherUserID(for userID: UUID) -> UUID? {
        if userAId == userID {
            return userBId
        }

        if userBId == userID {
            return userAId
        }

        return nil
    }

    private static func orderedPair(_ firstID: UUID, _ secondID: UUID) -> (UUID, UUID) {
        firstID.uuidString < secondID.uuidString ? (firstID, secondID) : (secondID, firstID)
    }
}
