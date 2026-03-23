import Foundation

@MainActor
final class PlacesViewModel: ObservableObject {
    @Published private(set) var placeItems: [PlaceListItem] = []
    @Published private(set) var availableCategoryOptions: [PlaceCategoryOption] = [.restaurants]
    @Published var selectedCategoryOption: PlaceCategoryOption = .restaurants
    @Published var sourceFilterMode: ReviewSourceFilterMode = .mineAndFriends
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let sessionStore: SessionStore
    private let friendRepository: FriendRepository
    private let userRepository: UserProfileRepository
    private let categoryRepository: CategoryRepository
    private let placeRepository: PlaceRepository
    private let placeReviewRepository: PlaceReviewRepository

    init(
        sessionStore: SessionStore,
        friendRepository: FriendRepository,
        userRepository: UserProfileRepository,
        categoryRepository: CategoryRepository,
        placeRepository: PlaceRepository,
        placeReviewRepository: PlaceReviewRepository
    ) {
        self.sessionStore = sessionStore
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
            let friends = try friendRepository.acceptedFriends(for: currentUser.id)
            let friendIDs = Set(friends.map(\.id))
            let authorIDs = resolvedAuthorIDs(currentUserID: currentUser.id, friendIDs: friendIDs)
            let visibleReviews = try placeReviewRepository.reviews(authoredBy: authorIDs, ratingRange: 1...10)
            let placeIDs = Set(visibleReviews.map(\.placeId))
            let visiblePlaces = try placeRepository.places(withIDs: placeIDs)

            let ownedCategories = try categoryRepository.categories(for: currentUser.id)
            availableCategoryOptions = [.restaurants] + ownedCategories.map {
                PlaceCategoryOption(id: $0.id.uuidString, title: $0.name, categoryID: $0.id)
            }
            if !availableCategoryOptions.contains(selectedCategoryOption) {
                selectedCategoryOption = .restaurants
            }

            let allUsers = try userRepository.allKnownUsers()
            var userNames = Dictionary(uniqueKeysWithValues: allUsers.map { ($0.id, $0.displayName) })
            userNames[currentUser.id] = currentUser.displayName

            let categoryNamesByPlace = try Dictionary(uniqueKeysWithValues: visiblePlaces.map { place in
                let names = try categoryRepository.categories(forPlace: place.id).map(\.name)
                return (place.id, names)
            })

            let groupedReviews = Dictionary(grouping: visibleReviews, by: \.placeId)
            let selectedCategoryID = selectedCategoryOption.categoryID

            placeItems = visiblePlaces.compactMap { place in
                guard let reviews = groupedReviews[place.id], !reviews.isEmpty else {
                    return nil
                }

                let categoryNames = categoryNamesByPlace[place.id] ?? []
                if let selectedCategoryID {
                    let matchesCategory = ownedCategories.first(where: { $0.id == selectedCategoryID }).map { categoryNames.contains($0.name) } ?? false
                    guard matchesCategory else {
                        return nil
                    }
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
                            reviewText: $0.reviewText
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
