import Foundation

@MainActor
final class FeedViewModel: ObservableObject {
    @Published private(set) var feedItems: [FeedPlaceActivityItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let sessionStore: SessionStore
    private let cloudKitSyncService: CloudKitSyncService
    private let feedRepository: FeedRepository
    private let friendRepository: FriendRepository
    private let userRepository: UserProfileRepository
    private let placeRepository: PlaceRepository
    private let placeReviewRepository: PlaceReviewRepository

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

    func load() async {
        guard let currentUser = sessionStore.currentUser else {
            errorMessage = AppError.missingCurrentUser.errorDescription
            feedItems = []
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let friends = try await friendRepository.acceptedFriends(for: currentUser.id)
            try await cloudKitSyncService.refreshFriendVisibleContent(for: currentUser, friends: friends)
            let friendIDs = Set(friends.map(\.id))
            let actorIDs = friendIDs.union([currentUser.id])
            let activities = try feedRepository.placeFeed(actorIDs: actorIDs)
            let users = try userRepository.allKnownUsers()
            var userNames = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0.displayName) })
            userNames[currentUser.id] = currentUser.displayName

            let visibleReviews = try placeReviewRepository.reviews(
                authoredBy: actorIDs,
                visibleTo: currentUser.id,
                friendIDs: friendIDs,
                ratingRange: 1...10
            )
            let reviewsByID = Dictionary(uniqueKeysWithValues: visibleReviews.map { ($0.id, $0) })
            let placeIDs = Set(visibleReviews.map(\.placeId))
            let places = try placeRepository.places(withIDs: placeIDs)
            let placesByID = Dictionary(uniqueKeysWithValues: places.map { ($0.id, $0) })

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
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
            feedItems = []
        }

        isLoading = false
    }
}
