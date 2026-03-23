import Foundation

@MainActor
final class FriendsViewModel: ObservableObject {
    @Published private(set) var friends: [User] = []
    @Published private(set) var incomingRequests: [FriendRelation] = []
    @Published private(set) var outgoingRequests: [FriendRelation] = []
    @Published private(set) var searchResults: [User] = []
    @Published private(set) var userLookup: [UUID: User] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isSearchPresented = false
    @Published var searchQuery = ""

    private let sessionStore: SessionStore
    private let userRepository: UserProfileRepository
    private let friendRepository: FriendRepository

    init(
        sessionStore: SessionStore,
        userRepository: UserProfileRepository,
        friendRepository: FriendRepository
    ) {
        self.sessionStore = sessionStore
        self.userRepository = userRepository
        self.friendRepository = friendRepository
    }

    func load() async {
        guard let currentUser = sessionStore.currentUser else {
            errorMessage = AppError.missingCurrentUser.errorDescription
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            friends = try friendRepository.acceptedFriends(for: currentUser.id)
            incomingRequests = try friendRepository.incomingRequests(for: currentUser.id)
            outgoingRequests = try friendRepository.outgoingRequests(for: currentUser.id)
            let knownUsers = try userRepository.allKnownUsers()
            userLookup = Dictionary(uniqueKeysWithValues: knownUsers.map { ($0.id, $0) })
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
        }

        isLoading = false
    }

    func searchUsers() async {
        guard let currentUser = sessionStore.currentUser else {
            errorMessage = AppError.missingCurrentUser.errorDescription
            return
        }

        do {
            searchResults = try userRepository.searchUsers(query: searchQuery, excluding: currentUser.id)
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
        }
    }

    func sendRequest(to user: User) async {
        guard let currentUser = sessionStore.currentUser else {
            errorMessage = AppError.missingCurrentUser.errorDescription
            return
        }

        do {
            try friendRepository.sendRequest(from: currentUser.id, to: user.id)
            await load()
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
        }
    }

    func accept(_ relation: FriendRelation) async {
        do {
            try friendRepository.acceptRequest(relation.id)
            await load()
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
        }
    }

    func reject(_ relation: FriendRelation) async {
        do {
            try friendRepository.rejectRequest(relation.id)
            await load()
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
        }
    }

    func removeFriend(_ user: User) async {
        guard let currentUser = sessionStore.currentUser else {
            errorMessage = AppError.missingCurrentUser.errorDescription
            return
        }

        do {
            try friendRepository.removeFriend(currentUserID: currentUser.id, friendID: user.id)
            await load()
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
        }
    }

    func name(for relation: FriendRelation, incoming: Bool) -> String {
        let userID = incoming ? relation.ownerUserId : relation.targetUserId
        return userLookup[userID]?.displayName ?? "Friend"
    }
}
