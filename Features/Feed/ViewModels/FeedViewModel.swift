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
            let friends = (try? await friendRepository.acceptedFriends(for: currentUser.id)) ?? []
            await cloudKitSyncService.refreshFriendVisibleContentIfPossible(for: currentUser, friends: friends)
            let friendIDs = Set(friends.map(\.id))
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
        } catch {
            logger.error("Unable to load feed: \(error.localizedDescription, privacy: .public)")
            errorMessage = AppError.wrap(error).errorDescription
            feedItems = []
        }

        isLoading = false
    }
}
