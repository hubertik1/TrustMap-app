import Foundation
import OSLog

@MainActor
final class PlacesViewModel: ObservableObject {
    @Published private(set) var placeItems: [PlaceListItem] = []
    @Published private(set) var availableCategoryOptions: [PlaceCategoryOption] = [.all, .restaurants]
    @Published var selectedCategoryOption: PlaceCategoryOption = .restaurants
    @Published var sourceFilterMode: ReviewSourceFilterMode = .mineAndFriends
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let logger = Logger(subsystem: "TrustMap", category: "PlacesViewModel")
    private let sessionStore: SessionStore
    private let cloudKitSyncService: CloudKitSyncService
    private let friendRepository: FriendRepository
    private let userRepository: UserProfileRepository
    private let categoryRepository: CategoryRepository
    private let placeRepository: PlaceRepository
    private let placeReviewRepository: PlaceReviewRepository

    init(
        sessionStore: SessionStore,
        cloudKitSyncService: CloudKitSyncService,
        friendRepository: FriendRepository,
        userRepository: UserProfileRepository,
        categoryRepository: CategoryRepository,
        placeRepository: PlaceRepository,
        placeReviewRepository: PlaceReviewRepository
    ) {
        self.sessionStore = sessionStore
        self.cloudKitSyncService = cloudKitSyncService
        self.friendRepository = friendRepository
        self.userRepository = userRepository
        self.categoryRepository = categoryRepository
        self.placeRepository = placeRepository
        self.placeReviewRepository = placeReviewRepository
    }

    var filterSummary: String {
        "\(selectedCategoryOption.title) • \(sourceFilterMode.displayName)"
    }

    func load() async {
        guard let currentUser = sessionStore.currentUser else {
            errorMessage = AppError.missingCurrentUser.errorDescription
            placeItems = []
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let friends = (try? await friendRepository.acceptedFriends(for: currentUser.id)) ?? []
            await cloudKitSyncService.refreshFriendVisibleContentIfPossible(for: currentUser, friends: friends)
            let friendIDs = Set(friends.map(\.id))
            let authorIDs = resolvedAuthorIDs(currentUserID: currentUser.id, friendIDs: friendIDs)
            let visibleReviews = try placeReviewRepository.reviews(
                authoredBy: authorIDs,
                visibleTo: currentUser.id,
                friendIDs: friendIDs,
                ratingRange: 1...10
            )
            let placeIDs = Set(visibleReviews.map(\.placeId))
            let visiblePlaces = try placeRepository.places(withIDs: placeIDs)

            _ = try categoryRepository.defaultRestaurantCategory(for: currentUser.id)
            let ownedCategories = try categoryRepository.categories(for: currentUser.id)
            let customCategoryOptions = ownedCategories
                .filter { $0.name.caseInsensitiveCompare(PlaceCategoryOption.restaurants.title) != .orderedSame }
                .map(PlaceCategoryOption.init(category:))
            availableCategoryOptions = [.all, .restaurants] + customCategoryOptions
            if !availableCategoryOptions.contains(selectedCategoryOption) {
                selectedCategoryOption = .restaurants
            }

            let allUsers = try userRepository.allKnownUsers()
            var userNames: [UUID: String] = allUsers.reduce(into: [:]) { result, user in
                result[user.id] = user.displayName
            }
            userNames[currentUser.id] = currentUser.displayName

            let categoryNamesByPlace = try visiblePlaces.reduce(into: [UUID: [String]]()) { result, place in
                result[place.id] = try categoryRepository.categoryNames(forPlace: place.id)
            }

            let groupedReviews = Dictionary(grouping: visibleReviews, by: \.placeId)

            placeItems = visiblePlaces.compactMap { place in
                guard let reviews = groupedReviews[place.id], !reviews.isEmpty else {
                    return nil
                }

                let categoryNames = categoryNamesByPlace[place.id] ?? []
                guard selectedCategoryOption.matches(categoryNames: categoryNames) else {
                    return nil
                }

                let average = Double(reviews.reduce(0) { $0 + $1.ratingOverall }) / Double(reviews.count)
                let reviewerRatings = reviews
                    .sorted { lhs, rhs in
                        if lhs.ratingOverall == rhs.ratingOverall {
                            return lhs.updatedAt > rhs.updatedAt
                        }
                        return lhs.ratingOverall > rhs.ratingOverall
                    }
                    .map {
                        PlaceReviewerRating(
                            id: $0.id,
                            reviewerID: $0.authorUserId,
                            reviewerName: userNames[$0.authorUserId] ?? "Friend",
                            rating: $0.ratingOverall,
                            descriptionText: $0.descriptionText
                        )
                    }

                return PlaceListItem(
                    id: place.id,
                    place: place,
                    averageRating: average,
                    reviewCount: reviews.count,
                    categoryNames: categoryNames,
                    reviewerRatings: reviewerRatings
                )
            }
            .sorted { lhs, rhs in
                if lhs.averageRating == rhs.averageRating {
                    return lhs.place.name.localizedStandardCompare(rhs.place.name) == .orderedAscending
                }
                return lhs.averageRating > rhs.averageRating
            }
        } catch {
            logger.error("Unable to load places: \(error.localizedDescription, privacy: .public)")
            errorMessage = AppError.wrap(error).errorDescription
            placeItems = []
        }

        isLoading = false
    }

    func apply(category option: PlaceCategoryOption) async {
        selectedCategoryOption = option
        await load()
    }

    func apply(sourceFilter mode: ReviewSourceFilterMode) async {
        sourceFilterMode = mode
        await load()
    }

    private func resolvedAuthorIDs(currentUserID: UUID, friendIDs: Set<UUID>) -> Set<UUID> {
        switch sourceFilterMode {
        case .mineOnly:
            return [currentUserID]
        case .friendsOnly:
            return friendIDs
        case .mineAndFriends:
            return friendIDs.union([currentUserID])
        }
    }
}
