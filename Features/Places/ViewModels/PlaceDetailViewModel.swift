import Foundation
import OSLog

@MainActor
final class PlaceDetailViewModel: ObservableObject {
    @Published private(set) var averageRating: Double?
    @Published private(set) var placeReviews: [PlaceReview] = []
    @Published private(set) var dishReviews: [DishReview] = []
    @Published private(set) var placePhotos: [PhotoAsset] = []
    @Published private(set) var currentUserPlaceReview: PlaceReview?
    @Published private(set) var currentUserID: UUID?
    @Published var editingDishReview: DishReview?
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var isPresentingAddPlaceReview = false
    @Published var isPresentingAddDishReview = false

    let place: Place

    private let logger = Logger(subsystem: "TrustMap", category: "PlaceDetailViewModel")
    private let sessionStore: SessionStore
    private let placeRepository: PlaceRepository
    private let placeReviewRepository: PlaceReviewRepository
    private let dishReviewRepository: DishReviewRepository

    init(
        place: Place,
        sessionStore: SessionStore,
        placeRepository: PlaceRepository,
        placeReviewRepository: PlaceReviewRepository,
        dishReviewRepository: DishReviewRepository
    ) {
        self.place = place
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

        errorMessage = nil
        currentUserID = currentUser.id
        isLoading = true

        do {
            async let details = placeRepository.fetchPlaceDetails(id: place.id)
            async let placeReviews = placeReviewRepository.fetchReviews(placeID: place.id)
            async let dishReviews = dishReviewRepository.fetchReviews(placeID: place.id)

            let resolvedDetails = try await details
            let resolvedPlaceReviews = try await placeReviews
            let resolvedDishReviews = try await dishReviews

            self.averageRating = resolvedDetails.averagePlaceRating
            self.placeReviews = resolvedPlaceReviews
            self.dishReviews = resolvedDishReviews
            self.currentUserPlaceReview = resolvedPlaceReviews.first(where: { $0.authorUserId == currentUser.id })
            self.placePhotos = (resolvedPlaceReviews.flatMap(\.photos) + resolvedDishReviews.flatMap(\.photos))
                .sorted { $0.createdAt > $1.createdAt }
        } catch {
            logger.error("Unable to load place details: \(error.localizedDescription, privacy: .public)")
            errorMessage = AppError.wrap(error).errorDescription
        }

        isLoading = false
    }

    var placeReviewButtonTitle: String {
        currentUserPlaceReview == nil ? "Add Place Review" : "Edit Place Review"
    }

    func canEdit(_ review: DishReview) -> Bool {
        review.authorUserId == currentUserID
    }

    func beginEditing(_ review: DishReview) {
        editingDishReview = review
    }

    func authorName(for userID: UUID) -> String {
        if let review = placeReviews.first(where: { $0.authorUserId == userID }) {
            return review.author.displayName
        }

        if let review = dishReviews.first(where: { $0.authorUserId == userID }) {
            return review.author.displayName
        }

        return "TrustMap User"
    }
}
