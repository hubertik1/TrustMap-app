import Foundation

@MainActor
final class UserFriendsViewModel: ObservableObject {
    @Published private(set) var friends: [UserFriendListItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var activeUserID: UUID?
    @Published var errorMessage: String?
    @Published var isPrivate = false

    private let targetUserID: UUID
    private let refreshCenter: AppRefreshCenter
    private let friendRepository: FriendRepository

    init(
        targetUserID: UUID,
        refreshCenter: AppRefreshCenter,
        friendRepository: FriendRepository
    ) {
        self.targetUserID = targetUserID
        self.refreshCenter = refreshCenter
        self.friendRepository = friendRepository
    }

    func load() async {
        errorMessage = nil
        isPrivate = false
        isLoading = true
        defer { isLoading = false }

        do {
            friends = try await friendRepository.fetchFriends(of: targetUserID)
        } catch {
            guard !Self.isCancellation(error) else { return }
            let wrappedError = AppError.wrap(error)
            if case .authFailed(let message) = wrappedError,
               message.localizedCaseInsensitiveContains("private") {
                isPrivate = true
                friends = []
                return
            }

            errorMessage = wrappedError.errorDescription
        }
    }

    func sendRequest(to item: UserFriendListItem) async {
        guard activeUserID == nil, item.relationshipStatus == .none else { return }

        activeUserID = item.id
        errorMessage = nil
        defer { activeUserID = nil }

        do {
            _ = try await friendRepository.sendRequest(to: item.id)
            updateRelationshipStatus(for: item.id, relationshipStatus: .outgoingRequest)
            refreshCenter.invalidateAll()
        } catch {
            guard !Self.isCancellation(error) else { return }
            errorMessage = AppError.wrap(error).errorDescription
        }
    }

    private func updateRelationshipStatus(for userID: UUID, relationshipStatus: RelationshipStatus) {
        friends = friends.map { item in
            guard item.id == userID else { return item }
            return UserFriendListItem(
                user: item.user,
                friendsSinceUtc: item.friendsSinceUtc,
                relationshipStatus: relationshipStatus
            )
        }
    }

    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }
}
