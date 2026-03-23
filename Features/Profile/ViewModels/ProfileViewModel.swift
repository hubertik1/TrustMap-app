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
    private let placeRepository: PlaceRepository
    private let placeReviewRepository: PlaceReviewRepository
    private let dishReviewRepository: DishReviewRepository

    init(
        sessionStore: SessionStore,
        placeRepository: PlaceRepository,
        placeReviewRepository: PlaceReviewRepository,
        dishReviewRepository: DishReviewRepository
    ) {
        self.sessionStore = sessionStore
        self.placeRepository = placeRepository
        self.placeReviewRepository = placeReviewRepository
        self.dishReviewRepository = dishReviewRepository
    }

    func load() async {
        guard let currentUser = sessionStore.currentUser else {
            errorMessage = AppError.missingCurrentUser.errorDescription
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            user = currentUser
            placeReviews = try placeReviewRepository.reviews(authoredBy: currentUser.id)
            dishReviews = try dishReviewRepository.reviews(authoredBy: currentUser.id)
            stats = UserStats(
                ratedPlacesCount: Set(placeReviews.map(\.placeId)).count,
                reviewedDishesCount: dishReviews.count
            )

            let placeIDs = Set(placeReviews.map(\.placeId) + dishReviews.map(\.placeId))
            let places = try placeRepository.places(withIDs: placeIDs)
            placeNames = Dictionary(uniqueKeysWithValues: places.map { ($0.id, $0.name) })
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
        }

        isLoading = false
    }
}
