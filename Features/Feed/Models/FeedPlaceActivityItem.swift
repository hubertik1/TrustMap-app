import Foundation

struct FeedPlaceActivityItem: Identifiable {
    let id: UUID
    let place: Place
    let title: String
    let subtitle: String
    let createdAt: Date
}
