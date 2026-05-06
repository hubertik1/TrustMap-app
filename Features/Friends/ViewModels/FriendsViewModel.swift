import Foundation

@MainActor
final class FriendsViewModel: ObservableObject {
    struct FriendListItem: Identifiable, Equatable {
        let id: UUID
        let userID: UUID
        let user: UserSummary
        let displayName: String
        let handle: String
        let avatarURL: URL?
        let bio: String?
        let addedAt: Date
    }

    struct RequestListItem: Identifiable, Equatable {
        let id: UUID
        let userID: UUID
        let displayName: String
        let handle: String
        let avatarURL: URL?
        let bio: String?
        let createdAt: Date
    }

    struct SearchResultItem: Identifiable, Equatable {
        let id: UUID
        let userID: UUID
        let displayName: String
        let handle: String
        let avatarURL: URL?
        let relationshipStatus: RelationshipStatus
    }

    @Published private(set) var friends: [FriendListItem] = []
    @Published private(set) var incomingRequests: [RequestListItem] = []
    @Published private(set) var outgoingRequests: [RequestListItem] = []
    @Published private(set) var searchResults: [SearchResultItem] = []
    @Published var searchText = ""
    @Published var isLoading = false
    @Published private(set) var isSearching = false
    @Published var errorMessage: String?
    @Published private(set) var activeUserID: UUID?
    @Published private(set) var hasLoadedRelationships = false

    private let refreshCenter: AppRefreshCenter
    private let userRepository: UserProfileRepository
    private let friendRepository: FriendRepository
    private var searchTask: Task<Void, Never>?

    init(
        refreshCenter: AppRefreshCenter,
        userRepository: UserProfileRepository,
        friendRepository: FriendRepository
    ) {
        self.refreshCenter = refreshCenter
        self.userRepository = userRepository
        self.friendRepository = friendRepository
    }

    var hasAnyEntries: Bool {
        !friends.isEmpty || !incomingRequests.isEmpty || !outgoingRequests.isEmpty
    }

    func load() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            async let friends = friendRepository.fetchFriends()
            async let incoming = friendRepository.fetchIncomingRequests()
            async let outgoing = friendRepository.fetchOutgoingRequests()

            self.friends = try await friends.map {
                FriendListItem(
                    id: $0.id,
                    userID: $0.user.id,
                    user: $0.user,
                    displayName: $0.user.displayName,
                    handle: $0.user.handle,
                    avatarURL: $0.user.avatarURL,
                    bio: nil,
                    addedAt: $0.createdAt
                )
            }

            self.incomingRequests = try await incoming.map {
                RequestListItem(
                    id: $0.id,
                    userID: $0.sender.id,
                    displayName: $0.sender.displayName,
                    handle: $0.sender.handle,
                    avatarURL: $0.sender.avatarURL,
                    bio: nil,
                    createdAt: $0.createdAt
                )
            }

            self.outgoingRequests = try await outgoing.map {
                RequestListItem(
                    id: $0.id,
                    userID: $0.receiver.id,
                    displayName: $0.receiver.displayName,
                    handle: $0.receiver.handle,
                    avatarURL: $0.receiver.avatarURL,
                    bio: nil,
                    createdAt: $0.createdAt
                )
            }
            hasLoadedRelationships = true
            errorMessage = nil
        } catch {
            guard !Self.isCancellation(error) else { return }
            errorMessage = AppError.wrap(error).errorDescription
        }
    }

    func handleSearchTextChange() {
        searchTask?.cancel()

        let normalized = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            searchResults = []
            isSearching = false
            errorMessage = nil
            return
        }

        isSearching = true
        searchResults = []
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            await self?.searchUsers()
        }
    }

    func sendRequest(to result: SearchResultItem) async {
        await performMutation(for: result.userID) {
            _ = try await friendRepository.sendRequest(to: result.userID)
            await load()
            await searchUsers()
        }
    }

    func accept(_ request: RequestListItem) async {
        await performMutation(for: request.userID) {
            _ = try await friendRepository.acceptRequest(id: request.id)
            await load()
            await searchUsers()
        }
    }

    func reject(_ request: RequestListItem) async {
        await performMutation(for: request.userID) {
            _ = try await friendRepository.rejectRequest(id: request.id)
            await load()
            await searchUsers()
        }
    }

    func cancel(_ request: RequestListItem) async {
        await performMutation(for: request.userID) {
            _ = try await friendRepository.cancelRequest(id: request.id)
            await load()
            await searchUsers()
        }
    }

    func remove(friend: FriendListItem) async {
        await performMutation(for: friend.userID) {
            try await friendRepository.removeFriend(userID: friend.userID)
            await load()
            await searchUsers()
        }
    }

    private func searchUsers() async {
        let normalized = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true
        defer { isSearching = false }

        do {
            let results = try await userRepository.searchUsers(query: normalized)
            searchResults = results.map {
                SearchResultItem(
                    id: $0.user.id,
                    userID: $0.user.id,
                    displayName: $0.user.displayName,
                    handle: $0.user.handle,
                    avatarURL: $0.user.avatarURL,
                    relationshipStatus: $0.relationshipStatus
                )
            }
            errorMessage = nil
        } catch {
            guard !Self.isCancellation(error) else { return }
            errorMessage = AppError.wrap(error).errorDescription
        }
    }

    private func performMutation(for userID: UUID, action: () async throws -> Void) async {
        guard activeUserID == nil else { return }

        activeUserID = userID
        errorMessage = nil
        defer { activeUserID = nil }

        do {
            try await action()
            refreshCenter.invalidateAll()
        } catch {
            guard !Self.isCancellation(error) else { return }
            errorMessage = AppError.wrap(error).errorDescription
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
