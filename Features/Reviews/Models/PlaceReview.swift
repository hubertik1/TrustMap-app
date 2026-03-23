import Foundation
import SwiftData

@Model
final class PlaceReview {
    var id: UUID
    var placeId: UUID
    var authorUserId: UUID
    var ratingOverall: Int
    var reviewText: String
    var descriptionText: String
    var visibility: VisibilityStatus
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        placeId: UUID,
        authorUserId: UUID,
        ratingOverall: Int,
        reviewText: String,
        descriptionText: String,
        visibility: VisibilityStatus = .friendsOnly,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.placeId = placeId
        self.authorUserId = authorUserId
        self.ratingOverall = ratingOverall
        self.reviewText = reviewText
        self.descriptionText = descriptionText
        self.visibility = visibility
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
