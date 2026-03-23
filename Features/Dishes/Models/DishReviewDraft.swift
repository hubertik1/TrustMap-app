import Foundation

struct DishReviewDraft: Sendable {
    let placeId: UUID
    let authorUserId: UUID
    let placeReviewId: UUID?
    let dishName: String
    let dishCategory: String?
    let dishRating: Int
    let dishReviewText: String
    let price: Double?
    let photoData: Data?
}
