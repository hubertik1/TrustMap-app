import Foundation

@MainActor
final class FeedViewModel: ObservableObject {
    @Published private(set) var activityItems: [ActivityItem] = []
    @Published private(set) var actorNames: [UUID: String] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let sessionStore: SessionStore
    private let feedRepository: FeedRepository
    private let friendRepository: FriendRepository
    private let userRepository: UserProfileRepository

    init(
        sessionStore: SessionStore,
        feedRepository: FeedRepository,
        friendRepository: FriendRepository,
        userRepository: UserProfileRepository
    ) {
        self.sessionStore = sessionStore
        self.feedRepository = feedRepository
        self.friendRepository = friendRepository
        self.userRepository = userRepository
    }

    func load() async {
        guard let currentUser = sessionStore.currentUser else {
            errorMessage = AppError.missingCurrentUser.errorDescription
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let friendIDs = try friendRepository.acceptedFriendIDs(for: currentUser.id)
            activityItems = try feedRepository.feed(for: currentUser.id, friendIDs: friendIDs)
            let users = try userRepository.allKnownUsers()
            actorNames = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0.displayName) })
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
        }

        isLoading = false
    }

    func title(for item: ActivityItem) -> String {
        let actorName = actorNames[item.actorUserId] ?? "A friend"

        switch item.type {
        case .placeReviewAdded:
            return "\(actorName) rated a place"
        case .dishReviewAdded:
            return "\(actorName) reviewed a dish"
        case .photoAdded:
            return "\(actorName) shared a photo"
        }
    }
}
