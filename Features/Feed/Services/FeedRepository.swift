import Foundation

@MainActor
final class FeedRepository {
    private struct FeedResponse: Decodable {
        let items: [FeedItem]
        let nextCursorUtc: Date?
    }

    private struct FeedItem: Decodable {
        let activityType: String
        let itemId: UUID
        let visibility: VisibilityStatus
        let createdAtUtc: Date
        let updatedAtUtc: Date
        let author: UserSummary
        let place: Place
        let rating: Int
        let body: String
        let title: String?
        let dishName: String?
        let photos: [PhotoAsset]

        var activityKind: FeedActivityKind {
            activityType == "DishReview" ? .dishReview : .placeReview
        }
    }

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func fetchFeed(before date: Date? = nil, take: Int = 20) async throws -> [FeedPlaceActivityItem] {
        var queryItems = [URLQueryItem(name: "take", value: String(take))]
        if let date {
            queryItems.append(URLQueryItem(name: "beforeUtc", value: Self.dateQueryValue(from: date)))
        }

        let response = try await apiClient.send(
            APIRequest<FeedResponse>(
                method: .get,
                path: "feed",
                queryItems: queryItems
            )
        )

        return response.items.map { item in
            FeedPlaceActivityItem(
                id: item.itemId,
                activityKind: item.activityKind,
                author: item.author,
                place: item.place,
                rating: item.rating,
                title: item.title?.nilIfEmpty,
                body: item.body,
                dishName: item.dishName?.nilIfEmpty,
                photos: item.photos,
                createdAt: item.updatedAtUtc
            )
        }
    }

    private static func dateQueryValue(from date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
