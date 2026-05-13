import Foundation

@MainActor
final class UserProfileRepository {
    enum AvatarUpdate {
        case keepExisting
        case remove
        case replace(imageData: Data)
    }

    private struct UpdateMePayload: Encodable {
        let handle: String
        let displayName: String
        let bio: String?
    }

    private struct UpdateMePrivacyPayload: Encodable {
        let reviewVisibility: VisibilityStatus
        let friendListVisibility: VisibilityStatus
        let profileVisibility: VisibilityStatus
        let profilePictureVisibility: VisibilityStatus
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
        avatarUpdate: AvatarUpdate = .keepExisting
    ) async throws -> User {
        let normalizedHandle = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedBio = bio?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty

        let updatedProfile = try await patchProfile(
            handle: normalizedHandle,
            displayName: normalizedDisplayName,
            bio: normalizedBio
        )

        switch avatarUpdate {
        case .keepExisting:
            return updatedProfile

        case .remove:
            return try await apiClient.send(
                APIRequest<User>(
                    method: .delete,
                    path: "me/avatar"
                )
            )

        case .replace(let imageData):
            let multipart = MultipartFormData(
                fields: [:],
                file: .init(
                    fieldName: "avatar",
                    fileName: "avatar.jpg",
                    mimeType: "image/jpeg",
                    data: imageData
                )
            )

            return try await apiClient.send(
                APIRequest<User>(
                    method: .put,
                    path: "me/avatar",
                    body: .multipart(multipart)
                )
            )
        }
    }

    private func patchProfile(
        handle: String,
        displayName: String,
        bio: String?
    ) async throws -> User {
        let payload = UpdateMePayload(
            handle: handle,
            displayName: displayName,
            bio: bio
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

    func updatePrivacySettings(
        reviewVisibility: VisibilityStatus,
        friendListVisibility: VisibilityStatus,
        profileVisibility: VisibilityStatus,
        profilePictureVisibility: VisibilityStatus
    ) async throws -> User {
        try await apiClient.send(
            APIRequest<User>(
                method: .patch,
                path: "me/privacy",
                body: .json(
                    AnyEncodable(
                        UpdateMePrivacyPayload(
                            reviewVisibility: reviewVisibility,
                            friendListVisibility: friendListVisibility,
                            profileVisibility: profileVisibility,
                            profilePictureVisibility: profilePictureVisibility
                        )
                    )
                )
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
