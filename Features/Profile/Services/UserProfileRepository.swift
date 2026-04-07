import Foundation

@MainActor
final class UserProfileRepository {
    private struct UpdateMePayload: Encodable {
        let handle: String
        let displayName: String
        let bio: String?
        let avatarUrl: String?
    }

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func fetchCurrentUser() async throws -> User {
        try await apiClient.send(
            APIRequest<User>(
                method: .get,
                path: "me"
            )
        )
    }

    func updateCurrentUser(
        handle: String,
        displayName: String,
        bio: String?,
        avatarURL: String?
    ) async throws -> User {
        let payload = UpdateMePayload(
            handle: handle.trimmingCharacters(in: .whitespacesAndNewlines),
            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            bio: bio?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            avatarUrl: avatarURL?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        )

        return try await apiClient.send(
            APIRequest<User>(
                method: .patch,
                path: "me",
                body: .json(AnyEncodable(payload))
            )
        )
    }

    func fetchUser(id: UUID) async throws -> User {
        try await apiClient.send(
            APIRequest<User>(
                method: .get,
                path: "users/\(id.uuidString)"
            )
        )
    }

    func searchUsers(query: String, take: Int = 20) async throws -> [UserSearchResult] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return []
        }

        return try await apiClient.send(
            APIRequest<[UserSearchResult]>(
                method: .get,
                path: "users/search",
                queryItems: [
                    URLQueryItem(name: "q", value: normalized),
                    URLQueryItem(name: "take", value: String(take))
                ]
            )
        )
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
