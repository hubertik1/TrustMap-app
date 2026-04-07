import Foundation

struct PlaceReviewDraft: Sendable {
    let placeId: UUID
    let ratingOverall: Int
    let reviewText: String
    let descriptionText: String
    let visibility: VisibilityStatus
    let photoDataItems: [Data]
    let photoIDsToDelete: [UUID]
    let selectedCategoryId: UUID?
}
