import Foundation

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var user: User?
    @Published private(set) var stats = UserStats(ratedPlacesCount: 0, reviewedDishesCount: 0)
    @Published private(set) var placeReviews: [PlaceReview] = []
    @Published private(set) var dishReviews: [DishReview] = []
    @Published private(set) var placeNames: [UUID: String] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let sessionStore: SessionStore
    private let userRepository: UserProfileRepository
    private let placeRepository: PlaceRepository
    private let placeReviewRepository: PlaceReviewRepository
    private let dishReviewRepository: DishReviewRepository

    init(
        sessionStore: SessionStore,
        userRepository: UserProfileRepository,
        placeRepository: PlaceRepository,
        placeReviewRepository: PlaceReviewRepository,
        dishReviewRepository: DishReviewRepository
    ) {
        self.sessionStore = sessionStore
        self.userRepository = userRepository
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
        stats = UserStats(
            ratedPlacesCount: Set(placeReviews.map(\.placeId)).count,
            reviewedDishesCount: dishReviews.count
        )

        let placeIDs = Set(placeReviews.map(\.placeId) + dishReviews.map(\.placeId))
        let places = try placeRepository.places(withIDs: placeIDs)
        placeNames = Dictionary(uniqueKeysWithValues: places.map { ($0.id, $0.name) })
    }
}
