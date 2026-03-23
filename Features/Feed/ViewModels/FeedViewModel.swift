import Foundation

@MainActor
final class FeedViewModel: ObservableObject {
    @Published private(set) var feedItems: [FeedPlaceActivityItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let sessionStore: SessionStore
    private let feedRepository: FeedRepository
    private let friendRepository: FriendRepository
    private let userRepository: UserProfileRepository
    private let placeRepository: PlaceRepository
    private let placeReviewRepository: PlaceReviewRepository

    init(
        sessionStore: SessionStore,
        feedRepository: FeedRepository,
        friendRepository: FriendRepository,
        userRepository: UserProfileRepository,
        placeRepository: PlaceRepository,
        placeReviewRepository: PlaceReviewRepository
    ) {
        self.sessionStore = sessionStore
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
            let friendIDs = try friendRepository.acceptedFriendIDs(for: currentUser.id)
            let actorIDs = friendIDs.union([currentUser.id])
            let activities = try feedRepository.placeFeed(actorIDs: actorIDs)
            let users = try userRepository.allKnownUsers()
            var userNames = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0.displayName) })
            userNames[currentUser.id] = currentUser.displayName

            let visibleReviews = try placeReviewRepository.reviews(authoredBy: actorIDs, ratingRange: 1...10)
            let reviewsByID = Dictionary(uniqueKeysWithValues: visibleReviews.map { ($0.id, $0) })
            let placeIDs = Set(visibleReviews.map(\.placeId))
            let places = try placeRepository.places(withIDs: placeIDs)
            let placeNames = Dictionary(uniqueKeysWithValues: places.map { ($0.id, $0.name) })

            feedItems = activities.compactMap { activity in
                guard let reviewID = UUID(uuidString: activity.referenceId),
                      let review = reviewsByID[reviewID] else {
                    return nil
                }

                return FeedPlaceActivityItem(
                    id: activity.id,
                    actorName: userNames[activity.actorUserId] ?? "Friend",
                    placeName: placeNames[review.placeId] ?? "Place",
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
