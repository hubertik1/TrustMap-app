import Foundation

@MainActor
final class NotificationRepository {
    private struct NotificationsResponse: Decodable {
        let items: [TrustMapNotification]
        let nextCursorUtc: Date?
    }

    private struct UnreadNotificationCountDto: Decodable {
        let count: Int
    }

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func fetchNotifications(before date: Date? = nil, take: Int = 50) async throws -> [TrustMapNotification] {
        var queryItems = [URLQueryItem(name: "take", value: String(take))]
        if let date {
            queryItems.append(URLQueryItem(name: "beforeUtc", value: Self.dateQueryValue(from: date)))
        }

        let response = try await apiClient.send(
            APIRequest<NotificationsResponse>(
                method: .get,
                path: "notifications",
                queryItems: queryItems
            )
        )

        _ = response.nextCursorUtc
        return response.items
    }

    func fetchUnreadCount() async throws -> Int {
        let response = try await apiClient.send(
            APIRequest<UnreadNotificationCountDto>(
                method: .get,
                path: "notifications/unread-count"
            )
        )

        return response.count
    }

    func markAsRead(id: UUID) async throws {
        _ = try await apiClient.send(
            APIRequest<EmptyResponse>(
                method: .patch,
                path: "notifications/\(id.uuidString)/read",
                acceptedStatusCodes: [204]
            )
        )
    }

    func markAllAsRead() async throws {
        _ = try await apiClient.send(
            APIRequest<EmptyResponse>(
                method: .patch,
                path: "notifications/read-all",
                acceptedStatusCodes: [204]
            )
        )
    }

    private static func dateQueryValue(from date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}
