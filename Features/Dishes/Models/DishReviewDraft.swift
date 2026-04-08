import Foundation

struct DishReviewDraft: Sendable {
    let placeId: UUID
    let placeReviewId: UUID?
    let visibility: VisibilityStatus
    let dishName: String
    let dishRating: Int
    let dishReviewText: String
    let price: Double?
    let photoData: Data?
    let photoIDsToDelete: [UUID]
    let selectedCategoryId: UUID?
}
