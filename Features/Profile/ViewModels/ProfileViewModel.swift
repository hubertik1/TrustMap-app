import Foundation

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var user: User?
    @Published private(set) var stats = UserStats(ratedPlacesCount: 0, reviewedDishesCount: 0, categoriesCount: 0)
    @Published private(set) var placeReviews: [PlaceReview] = []
    @Published private(set) var dishReviews: [DishReview] = []
    @Published private(set) var placeNames: [UUID: String] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let sessionStore: SessionStore
    private let userRepository: UserProfileRepository
    private let categoryRepository: CategoryRepository
    private let placeRepository: PlaceRepository
    private let placeReviewRepository: PlaceReviewRepository
    private let dishReviewRepository: DishReviewRepository

    init(
        sessionStore: SessionStore,
        userRepository: UserProfileRepository,
        categoryRepository: CategoryRepository,
        placeRepository: PlaceRepository,
        placeReviewRepository: PlaceReviewRepository,
        dishReviewRepository: DishReviewRepository
    ) {
        self.sessionStore = sessionStore
        self.userRepository = userRepository
        self.categoryRepository = categoryRepository
        self.placeRepository = placeRepository
        self.placeReviewRepository = placeReviewRepository
        self.dishReviewRepository = dishReviewRepository
        self.user = sessionStore.currentUser
    }

    func load() async {
        guard let currentUser = sessionStore.currentUser else {
            errorMessage = AppError.missingCurrentUser.errorDescription
            user = nil
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            user = try userRepository.user(withID: currentUser.id) ?? currentUser
            try reloadReviewData(for: currentUser.id)
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
        }

        isLoading = false
    }

    func deletePlaceReview(_ review: PlaceReview) async throws {
        guard let currentUser = sessionStore.currentUser else {
            throw AppError.missingCurrentUser
        }

        guard review.authorUserId == currentUser.id else {
            throw AppError.validationFailure("You can only delete your own place review.")
        }

        try placeReviewRepository.deleteReview(review)
        try reloadReviewData(for: currentUser.id)
    }

    func deleteDishReview(_ review: DishReview) async throws {
        guard let currentUser = sessionStore.currentUser else {
            throw AppError.missingCurrentUser
        }

        guard review.authorUserId == currentUser.id else {
            throw AppError.validationFailure("You can only delete your own dish review.")
        }

        try dishReviewRepository.deleteReview(review)
        try reloadReviewData(for: currentUser.id)
    }

    private func reloadReviewData(for userID: UUID) throws {
        placeReviews = try placeReviewRepository.reviews(authoredBy: userID)
        dishReviews = try dishReviewRepository.reviews(authoredBy: userID)
        let visibleCategories = try categoryRepository.categories(for: userID)
        stats = UserStats(
            ratedPlacesCount: Set(placeReviews.map(\.placeId)).count,
            reviewedDishesCount: dishReviews.count,
            categoriesCount: visibleCategories.count
        )

        let placeIDs = Set(placeReviews.map(\.placeId) + dishReviews.map(\.placeId))
        let places = try placeRepository.places(withIDs: placeIDs)
        placeNames = Dictionary(uniqueKeysWithValues: places.map { ($0.id, $0.name) })
    }
}

struct FriendCategorySuggestion: Identifiable {
    let id: UUID
    let category: CustomCategory
    let ownerName: String
}

@MainActor
final class CategoriesViewModel: ObservableObject {
    @Published private(set) var myCategories: [CustomCategory] = []
    @Published private(set) var hiddenCategories: [CustomCategory] = []
    @Published private(set) var friendCategories: [FriendCategorySuggestion] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let sessionStore: SessionStore
    private let categoryRepository: CategoryRepository
    private let friendRepository: FriendRepository
    private let userRepository: UserProfileRepository

    init(
        sessionStore: SessionStore,
        categoryRepository: CategoryRepository,
        friendRepository: FriendRepository,
        userRepository: UserProfileRepository
    ) {
        self.sessionStore = sessionStore
        self.categoryRepository = categoryRepository
        self.friendRepository = friendRepository
        self.userRepository = userRepository
    }

    func load() async {
        guard let currentUser = sessionStore.currentUser else {
            errorMessage = AppError.missingCurrentUser.errorDescription
            myCategories = []
            hiddenCategories = []
            friendCategories = []
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            _ = try categoryRepository.defaultRestaurantCategory(for: currentUser.id)

            myCategories = try categoryRepository.categories(for: currentUser.id)
            hiddenCategories = try categoryRepository.hiddenCategories(for: currentUser.id)

            let friends = try friendRepository.acceptedFriends(for: currentUser.id)
            let friendIDs = Set(friends.map(\.id))
            let friendCategories = try categoryRepository.categories(createdBy: friendIDs)
            let ownerNames = Dictionary(uniqueKeysWithValues: friends.map { ($0.id, $0.displayName) })
            let ownCategoryNames = Set((myCategories + hiddenCategories).map { normalizedName($0.name) })
            var seenFriendNames = Set<String>()

            self.friendCategories = friendCategories.compactMap { category in
                let normalizedName = normalizedName(category.name)
                guard !isDefaultCategory(category),
                      !ownCategoryNames.contains(normalizedName),
                      seenFriendNames.insert(normalizedName).inserted else {
                    return nil
                }

                return FriendCategorySuggestion(
                    id: category.id,
                    category: category,
                    ownerName: ownerNames[category.ownerUserId] ?? "Friend"
                )
            }
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
            myCategories = []
            hiddenCategories = []
            friendCategories = []
        }

        isLoading = false
    }

    func createCategory(named name: String) async {
        guard let currentUser = sessionStore.currentUser else {
            errorMessage = AppError.missingCurrentUser.errorDescription
            return
        }

        do {
            _ = try categoryRepository.createCategory(ownerUserID: currentUser.id, name: name)
            await load()
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
        }
    }

    func importCategory(_ suggestion: FriendCategorySuggestion) async {
        guard let currentUser = sessionStore.currentUser else {
            errorMessage = AppError.missingCurrentUser.errorDescription
            return
        }

        do {
            _ = try categoryRepository.importCategory(suggestion.category, to: currentUser.id)
            await load()
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
        }
    }

    func hideCategory(_ category: CustomCategory) async {
        await updateVisibility(for: category, isHidden: true)
    }

    func unhideCategory(_ category: CustomCategory) async {
        await updateVisibility(for: category, isHidden: false)
    }

    func deleteCategory(_ category: CustomCategory) async {
        guard let currentUser = sessionStore.currentUser else {
            errorMessage = AppError.missingCurrentUser.errorDescription
            return
        }

        do {
            try categoryRepository.deleteCategory(category.id, ownerUserID: currentUser.id)
            await load()
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
        }
    }

    func canDelete(_ category: CustomCategory) -> Bool {
        !isDefaultCategory(category)
    }

    func canHide(_ category: CustomCategory) -> Bool {
        !isDefaultCategory(category)
    }

    func secondaryLabel(for category: CustomCategory) -> String? {
        if isDefaultCategory(category) {
            return "Default"
        }

        return hiddenCategories.contains(where: { $0.id == category.id }) ? "Hidden" : nil
    }

    private func updateVisibility(for category: CustomCategory, isHidden: Bool) async {
        guard let currentUser = sessionStore.currentUser else {
            errorMessage = AppError.missingCurrentUser.errorDescription
            return
        }

        do {
            try categoryRepository.updateVisibility(for: category.id, ownerUserID: currentUser.id, isHidden: isHidden)
            await load()
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
        }
    }

    private func isDefaultCategory(_ category: CustomCategory) -> Bool {
        normalizedName(category.name) == normalizedName(PlaceCategoryOption.restaurants.title)
    }

    private func normalizedName(_ name: String) -> String {
        name
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
