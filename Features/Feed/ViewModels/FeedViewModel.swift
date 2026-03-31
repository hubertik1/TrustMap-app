import Foundation
import OSLog

@MainActor
final class FeedViewModel: ObservableObject {
    @Published private(set) var feedItems: [FeedPlaceActivityItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let logger = Logger(subsystem: "TrustMap", category: "FeedViewModel")
    private let sessionStore: SessionStore
    private let cloudKitSyncService: CloudKitSyncService
    private let feedRepository: FeedRepository
    private let friendRepository: FriendRepository
    private let userRepository: UserProfileRepository
    private let placeRepository: PlaceRepository
    private let placeReviewRepository: PlaceReviewRepository
    private var refreshTask: Task<Void, Never>?

    init(
        sessionStore: SessionStore,
        cloudKitSyncService: CloudKitSyncService,
        feedRepository: FeedRepository,
        friendRepository: FriendRepository,
        userRepository: UserProfileRepository,
        placeRepository: PlaceRepository,
        placeReviewRepository: PlaceReviewRepository
    ) {
        self.sessionStore = sessionStore
        self.cloudKitSyncService = cloudKitSyncService
        self.feedRepository = feedRepository
        self.friendRepository = friendRepository
        self.userRepository = userRepository
        self.placeRepository = placeRepository
        self.placeReviewRepository = placeReviewRepository
    }

    deinit {
        refreshTask?.cancel()
    }

    func load() async {
        guard let currentUser = sessionStore.currentUser else {
            errorMessage = AppError.missingCurrentUser.errorDescription
            feedItems = []
            return
        }

        errorMessage = nil
        if feedItems.isEmpty {
            isLoading = true
        }

        do {
            try reloadFeed(for: currentUser, friendIDs: friendRepository.cachedAcceptedFriendIDs(for: currentUser.id))
        } catch {
            logger.error("Unable to load feed: \(error.localizedDescription, privacy: .public)")
            errorMessage = AppError.wrap(error).errorDescription
            feedItems = []
        }

        isLoading = false
        scheduleBackgroundRefresh(for: currentUser)
    }

    private func reloadFeed(for currentUser: User, friendIDs: Set<UUID>) throws {
        let actorIDs = friendIDs.union([currentUser.id])
        let activities = try feedRepository.placeFeed(actorIDs: actorIDs)
        let users = try userRepository.allKnownUsers()
        var userNames: [UUID: String] = users.reduce(into: [:]) { result, user in
            result[user.id] = user.displayName
        }
        userNames[currentUser.id] = currentUser.displayName

        let visibleReviews = try placeReviewRepository.reviews(
            authoredBy: actorIDs,
            visibleTo: currentUser.id,
            friendIDs: friendIDs,
            ratingRange: 1...10
        )
        let reviewsByID: [UUID: PlaceReview] = visibleReviews.reduce(into: [:]) { result, review in
            result[review.id] = review
        }
        let placeIDs = Set(visibleReviews.map(\.placeId))
        let places = try placeRepository.places(withIDs: placeIDs)
        let placesByID: [UUID: Place] = places.reduce(into: [:]) { result, place in
            result[place.id] = place
        }

        feedItems = activities.compactMap { activity in
            guard let reviewID = UUID(uuidString: activity.referenceId),
                  let review = reviewsByID[reviewID],
                  let place = placesByID[review.placeId] else {
                return nil
            }

            return FeedPlaceActivityItem(
                id: activity.id,
                place: place,
                actorName: userNames[activity.actorUserId] ?? "Friend",
                placeName: place.name,
                rating: review.ratingOverall,
                createdAt: activity.createdAt
            )
        }
    }

    private func scheduleBackgroundRefresh(for currentUser: User) {
        refreshTask?.cancel()
        let currentUserID = currentUser.id

        refreshTask = Task { [weak self] in
            guard let self else {
                return
            }

            let cachedFriendIDs = (try? self.friendRepository.cachedAcceptedFriendIDs(for: currentUserID)) ?? Set<UUID>()
            let friends = (try? await self.friendRepository.acceptedFriends(for: currentUserID)) ?? []
            guard !Task.isCancelled,
                  let sessionUser = self.sessionStore.currentUser,
                  sessionUser.id == currentUserID else {
                return
            }

            await self.cloudKitSyncService.refreshFriendVisibleContentIfPossible(for: sessionUser, friends: friends)
            guard !Task.isCancelled else {
                return
            }

            do {
                try self.reloadFeed(
                    for: sessionUser,
                    friendIDs: (try? self.friendRepository.cachedAcceptedFriendIDs(for: currentUserID)) ?? cachedFriendIDs
                )
                self.errorMessage = nil
            } catch {
                self.logger.error("Unable to refresh feed in background: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
