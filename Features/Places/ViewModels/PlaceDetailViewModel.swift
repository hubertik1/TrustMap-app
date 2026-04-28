import Foundation
import OSLog

@MainActor
final class PlaceDetailViewModel: ObservableObject {
    @Published private(set) var place: Place
    @Published private(set) var averageRating: Double?
    @Published private(set) var categoryNames: [String] = []
    @Published private(set) var placeReviews: [PlaceReview] = []
    @Published private(set) var dishReviews: [DishReview] = []
    @Published private(set) var placePhotos: [PhotoAsset] = []
    @Published private(set) var currentUserPlaceReview: PlaceReview?
    @Published private(set) var currentUserID: UUID?
    @Published var editingDishReview: DishReview?
    @Published var customDisplayNameDraft = ""
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var isPresentingAddPlaceReview = false
    @Published var isPresentingAddDishReview = false
    @Published var isPresentingCustomNameEditor = false
    @Published var isSavingCustomName = false

    private let logger = Logger(subsystem: "TrustMap", category: "PlaceDetailViewModel")
    private let refreshCenter: AppRefreshCenter
    private let sessionStore: SessionStore
    private let placeRepository: PlaceRepository
    private let placeReviewRepository: PlaceReviewRepository
    private let dishReviewRepository: DishReviewRepository

    init(
        place: Place,
        refreshCenter: AppRefreshCenter,
        sessionStore: SessionStore,
        placeRepository: PlaceRepository,
        placeReviewRepository: PlaceReviewRepository,
        dishReviewRepository: DishReviewRepository
    ) {
        self.place = place
        self.refreshCenter = refreshCenter
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

            self.place = resolvedDetails.place
            self.averageRating = resolvedDetails.averagePlaceRating
            self.categoryNames = resolvedDetails.categoryNames
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

    var canAddDishReview: Bool {
        let effectiveCategoryNames = categoryNames.isEmpty ? place.categoryNames : categoryNames
        return effectiveCategoryNames.contains { categoryName in
            TrustMapCategory.isRestaurants(categoryName)
        }
    }

    var recentContributors: [UserSummary] {
        Array(sortedContributorActivities.prefix(3).map { $0.author })
    }

    var contributorCount: Int {
        sortedContributorActivities.count
    }

    func canEdit(_ review: DishReview) -> Bool {
        review.authorUserId == currentUserID
    }

    func beginEditing(_ review: DishReview) {
        editingDishReview = review
    }

    func beginPlaceReviewFlow() {
        isPresentingAddPlaceReview = true
    }

    var canRenameCustomPlace: Bool {
        place.canRenameCustomDisplayName(as: currentUserID)
    }

    var customPlaceActionTitle: String {
        place.customDisplayName == nil ? "Name Custom Place" : "Rename Custom Place"
    }

    func beginRenamingCustomPlace() {
        customDisplayNameDraft = place.customDisplayName ?? ""
        isPresentingCustomNameEditor = true
    }

    func saveCustomPlaceName() async {
        guard canRenameCustomPlace else {
            return
        }

        let trimmedDraft = customDisplayNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDraft.isEmpty else {
            errorMessage = "Enter a place name."
            return
        }

        errorMessage = nil
        isSavingCustomName = true
        defer { isSavingCustomName = false }

        do {
            let updatedPlace = try await placeRepository.updateCustomDisplayName(
                placeID: place.id,
                displayName: trimmedDraft
            )
            place = updatedPlace
            customDisplayNameDraft = updatedPlace.customDisplayName ?? ""
            isPresentingCustomNameEditor = false
            refreshCenter.invalidateAll()
        } catch {
            logger.error("Unable to update custom place name: \(error.localizedDescription, privacy: .public)")
            errorMessage = AppError.wrap(error).errorDescription
        }
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

    private var sortedContributorActivities: [(author: UserSummary, date: Date)] {
        let activities = placeReviews.map { review in
            (author: review.author, date: review.updatedAt)
        } + dishReviews.map { review in
            (author: review.author, date: review.updatedAt)
        }

        var latestByAuthorID: [UUID: (author: UserSummary, date: Date)] = [:]

        for activity in activities {
            if let existing = latestByAuthorID[activity.author.id],
               existing.date >= activity.date {
                continue
            }

            latestByAuthorID[activity.author.id] = activity
        }

        return latestByAuthorID.values.sorted { lhs, rhs in
            if lhs.date != rhs.date {
                return lhs.date > rhs.date
            }

            return lhs.author.id.uuidString < rhs.author.id.uuidString
        }
    }
}
