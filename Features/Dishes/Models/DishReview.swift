import Foundation
import SwiftData

@Model
final class DishReview {
    var id: UUID
    var placeId: UUID
    var authorUserId: UUID
    var placeReviewId: UUID?
    var dishName: String
    var dishRating: Int
    var dishReviewText: String
    var price: Double?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        placeId: UUID,
        authorUserId: UUID,
        placeReviewId: UUID? = nil,
        dishName: String,
        dishRating: Int,
        dishReviewText: String,
        price: Double? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.placeId = placeId
        self.authorUserId = authorUserId
        self.placeReviewId = placeReviewId
        self.dishName = dishName
        self.dishRating = dishRating
        self.dishReviewText = dishReviewText
        self.price = price
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
