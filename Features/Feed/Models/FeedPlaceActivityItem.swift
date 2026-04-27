import Foundation

enum FeedActivityKind: String, Hashable, Sendable {
    case placeReview
    case dishReview
}

struct FeedPlaceActivityItem: Identifiable, Hashable, Sendable {
    let id: UUID
    let activityKind: FeedActivityKind
    let author: UserSummary
    let place: Place
    let rating: Int
    let title: String?
    let body: String
    let dishName: String?
    let photos: [PhotoAsset]
    let createdAt: Date
}
