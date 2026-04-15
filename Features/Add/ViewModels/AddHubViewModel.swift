import Foundation

@MainActor
final class AddHubViewModel: ObservableObject {
    enum Flow: Identifiable, Equatable {
        case placeReview
        case dishReview

        var id: String {
            switch self {
            case .placeReview:
                return "placeReview"
            case .dishReview:
                return "dishReview"
            }
        }

        var title: String {
            switch self {
            case .placeReview:
                return "Add Place Review"
            case .dishReview:
                return "Add Dish Review"
            }
        }
    }

    @Published private(set) var recentPlaces: [Place] = []
    @Published private(set) var eligibleDishPlaces: [Place] = []
    @Published var errorMessage: String?

    private let sessionStore: SessionStore
    private let placeReviewRepository: PlaceReviewRepository
    private let dishReviewRepository: DishReviewRepository
    private var eligibleDishPlaceReviewIDs: [UUID: UUID] = [:]
    private var placeReviewsByPlaceID: [UUID: PlaceReview] = [:]

    init(
        sessionStore: SessionStore,
        placeReviewRepository: PlaceReviewRepository,
        dishReviewRepository: DishReviewRepository
    ) {
        self.sessionStore = sessionStore
        self.placeReviewRepository = placeReviewRepository
        self.dishReviewRepository = dishReviewRepository
    }

    func load() async {
        guard let currentUser = sessionStore.currentUser else {
            recentPlaces = []
            eligibleDishPlaces = []
            eligibleDishPlaceReviewIDs = [:]
            errorMessage = AppError.missingCurrentUser.errorDescription
            return
        }

        do {
            async let placeReviewsTask = placeReviewRepository.fetchReviews(authorUserID: currentUser.id)
            async let dishReviewsTask = dishReviewRepository.fetchReviews(authorUserID: currentUser.id)

            let placeReviews = try await placeReviewsTask
            let dishReviews = try await dishReviewsTask

            placeReviewsByPlaceID = placeReviews
                .sorted(by: { $0.updatedAt > $1.updatedAt })
                .reduce(into: [:]) { partialResult, review in
                    partialResult[review.placeId] = partialResult[review.placeId] ?? review
                }

            recentPlaces = Self.makeRecentPlaces(
                placeReviews: placeReviews,
                dishReviews: dishReviews
            )

            let eligibleEntries = Self.makeEligibleDishPlaceEntries(from: placeReviews)
            eligibleDishPlaces = eligibleEntries.map(\.place)
            eligibleDishPlaceReviewIDs = Dictionary(
                uniqueKeysWithValues: eligibleEntries.map { ($0.place.id, $0.placeReviewID) }
            )
            errorMessage = nil
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
        }
    }

    func isEligibleDishPlace(_ place: Place) -> Bool {
        eligibleDishPlaceReviewIDs[place.id] != nil
    }

    func placeReviewID(for place: Place) -> UUID? {
        eligibleDishPlaceReviewIDs[place.id]
    }

    func placeReview(for place: Place) -> PlaceReview? {
        placeReviewsByPlaceID[place.id]
    }

    func placeReviewActionTitle(for place: Place) -> String {
        placeReview(for: place) == nil ? "Add Place Review" : "Edit Place Review"
    }

    private static func makeRecentPlaces(
        placeReviews: [PlaceReview],
        dishReviews: [DishReview]
    ) -> [Place] {
        let entries =
            placeReviews.map { RecentPlaceEntry(place: $0.place, updatedAt: $0.updatedAt) }
            + dishReviews.map { RecentPlaceEntry(place: $0.place, updatedAt: $0.updatedAt) }

        return deduplicatedPlaces(
            from: entries.sorted { $0.updatedAt > $1.updatedAt }.map(\.place),
            limit: 6
        )
    }

    private static func makeEligibleDishPlaceEntries(from placeReviews: [PlaceReview]) -> [EligibleDishPlaceEntry] {
        var seenPlaceIDs = Set<UUID>()
        var entries: [EligibleDishPlaceEntry] = []

        for review in placeReviews.sorted(by: { $0.updatedAt > $1.updatedAt }) where review.supportsDishReviews {
            guard seenPlaceIDs.insert(review.placeId).inserted else {
                continue
            }

            entries.append(
                EligibleDishPlaceEntry(
                    place: review.place,
                    placeReviewID: review.id
                )
            )
        }

        return entries
    }

    private static func deduplicatedPlaces(from places: [Place], limit: Int) -> [Place] {
        var seenIDs = Set<UUID>()
        var uniquePlaces: [Place] = []

        for place in places where seenIDs.insert(place.id).inserted {
            uniquePlaces.append(place)
            if uniquePlaces.count == limit {
                break
            }
        }

        return uniquePlaces
    }
}

private struct RecentPlaceEntry {
    let place: Place
    let updatedAt: Date
}

private struct EligibleDishPlaceEntry {
    let place: Place
    let placeReviewID: UUID
}
