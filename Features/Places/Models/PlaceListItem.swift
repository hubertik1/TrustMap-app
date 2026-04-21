import Foundation

struct PlaceListItem: Identifiable, Hashable {
    let id: UUID
    let place: Place
    let averageRating: Double
    let reviewCount: Int
    let latestActivityAtUtc: Date
    let categoryNames: [String]
    let reviewerRatings: [PlaceReviewerRating]
    let createdByUserId: UUID?
}
