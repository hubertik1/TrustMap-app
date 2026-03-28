import Foundation

struct FeedPlaceActivityItem: Identifiable {
    let id: UUID
    let place: Place
    let actorName: String
    let placeName: String
    let rating: Int
    let createdAt: Date

    var title: String {
        "\(actorName) added \(placeName)"
    }

    var subtitle: String {
        "Rated \(rating)/10"
    }
}
