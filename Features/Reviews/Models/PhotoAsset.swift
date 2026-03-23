import Foundation
import SwiftData

@Model
final class PhotoAsset {
    var id: UUID
    var ownerUserId: UUID
    var placeId: UUID?
    var placeReviewId: UUID?
    var dishReviewId: UUID?
    var assetReference: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        ownerUserId: UUID,
        placeId: UUID? = nil,
        placeReviewId: UUID? = nil,
        dishReviewId: UUID? = nil,
        assetReference: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.ownerUserId = ownerUserId
        self.placeId = placeId
        self.placeReviewId = placeReviewId
        self.dishReviewId = dishReviewId
        self.assetReference = assetReference
        self.createdAt = createdAt
    }
}
