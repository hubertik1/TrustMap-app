import Foundation

struct PlaceReviewerRating: Identifiable, Hashable {
    let id: UUID
    let reviewerID: UUID
    let reviewerName: String
    let rating: Int
    let descriptionText: String
}
