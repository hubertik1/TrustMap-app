import Foundation

@MainActor
final class FriendRepository {
    private struct SendFriendRequestPayload: Encodable {
        let receiverUserId: UUID
    }

    private struct FriendDTO: Decodable {
        let user: UserSummary
        let friendsSinceUtc: Date
    }

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func fetchFriends() async throws -> [Friendship] {
        let response = try await apiClient.send(
            APIRequest<[FriendDTO]>(
                method: .get,
                path: "friends"
            )
        )

        return response.map {
            Friendship(id: $0.user.id, user: $0.user, createdAt: $0.friendsSinceUtc)
        }
    }

    func fetchIncomingRequests() async throws -> [FriendInvite] {
        try await apiClient.send(
            APIRequest<[FriendInvite]>(
                method: .get,
                path: "friend-requests/incoming"
            )
        )
    }

    func fetchOutgoingRequests() async throws -> [FriendInvite] {
        try await apiClient.send(
            APIRequest<[FriendInvite]>(
                method: .get,
                path: "friend-requests/outgoing"
            )
        )
    }

    func sendRequest(to userID: UUID) async throws -> FriendInvite {
        try await apiClient.send(
            APIRequest<FriendInvite>(
                method: .post,
                path: "friend-requests",
                body: .json(AnyEncodable(SendFriendRequestPayload(receiverUserId: userID))),
                acceptedStatusCodes: [201]
            )
        )
    }

    func acceptRequest(id: UUID) async throws -> Friendship {
        let response = try await apiClient.send(
            APIRequest<FriendDTO>(
                method: .post,
                path: "friend-requests/\(id.uuidString)/accept"
            )
        )

        return Friendship(id: response.user.id, user: response.user, createdAt: response.friendsSinceUtc)
    }

    func rejectRequest(id: UUID) async throws -> FriendInvite {
        try await apiClient.send(
            APIRequest<FriendInvite>(
                method: .post,
                path: "friend-requests/\(id.uuidString)/reject"
            )
        )
    }

    func cancelRequest(id: UUID) async throws -> FriendInvite {
        try await apiClient.send(
            APIRequest<FriendInvite>(
                method: .post,
                path: "friend-requests/\(id.uuidString)/cancel"
            )
        )
    }

    func removeFriend(userID: UUID) async throws {
        _ = try await apiClient.send(
            APIRequest<EmptyResponse>(
                method: .delete,
                path: "friends/\(userID.uuidString)",
                acceptedStatusCodes: [204]
            )
        )
    }
}
