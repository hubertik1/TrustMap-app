import Foundation
import MapKit

@MainActor
final class MapScreenViewModel: ObservableObject {
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.18, longitudeDelta: 0.18)
    )
    @Published var searchText = ""
    @Published var searchResults: [PlaceSearchResult] = []
    @Published var annotations: [MapPlaceAnnotation] = []
    @Published var availablePeople: [FilterPerson] = []
    @Published var filterState = MapFilterState()
    @Published var selectedPlace: Place?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isFilterPresented = false

    private let sessionStore: SessionStore
    private let friendRepository: FriendRepository
    private let userRepository: UserProfileRepository
    private let placeRepository: PlaceRepository
    private let placeReviewRepository: PlaceReviewRepository
    private let mapSearchService: MapSearchService

    init(
        sessionStore: SessionStore,
        friendRepository: FriendRepository,
        userRepository: UserProfileRepository,
        placeRepository: PlaceRepository,
        placeReviewRepository: PlaceReviewRepository,
        mapSearchService: MapSearchService
    ) {
        self.sessionStore = sessionStore
        self.friendRepository = friendRepository
        self.userRepository = userRepository
        self.placeRepository = placeRepository
        self.placeReviewRepository = placeReviewRepository
        self.mapSearchService = mapSearchService
    }

    func load() async {
        guard let currentUser = sessionStore.currentUser else {
            errorMessage = AppError.missingCurrentUser.errorDescription
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let friends = try friendRepository.acceptedFriends(for: currentUser.id)
            let friendIDs = Set(friends.map(\.id))
            availablePeople = [FilterPerson(id: currentUser.id, name: "Me", isCurrentUser: true)]
                + friends.map { FilterPerson(id: $0.id, name: $0.displayName, isCurrentUser: false) }

            let authorIDs = filterState.resolvedAuthorIDs(currentUserID: currentUser.id, friendIDs: friendIDs)
            let reviews = try placeReviewRepository.reviews(authoredBy: authorIDs, ratingRange: filterState.ratingRange)
            let places = try placeRepository.places(withIDs: Set(reviews.map(\.placeId)))
            annotations = buildAnnotations(from: reviews, places: places)
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
        }

        isLoading = false
    }

    func performSearch() async {
        isLoading = true
        errorMessage = nil

        do {
            searchResults = try await mapSearchService.search(query: searchText, region: region)
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
        }

        isLoading = false
    }

    func applyFilters() async {
        await load()
    }

    func selectAnnotation(_ annotation: MapPlaceAnnotation) {
        selectedPlace = annotation.place
    }

    func selectSearchResult(_ result: PlaceSearchResult) async {
        guard let currentUser = sessionStore.currentUser else {
            errorMessage = AppError.missingCurrentUser.errorDescription
            return
        }

        do {
            selectedPlace = try placeRepository.upsertPlace(from: result, createdByUserID: currentUser.id)
            searchResults = []
            searchText = ""
            region.center = result.coordinate
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
        }
    }

    func userName(for userID: UUID) -> String {
        if let person = availablePeople.first(where: { $0.id == userID }) {
            return person.name
        }

        return "Friend"
    }

    private func buildAnnotations(from reviews: [PlaceReview], places: [Place]) -> [MapPlaceAnnotation] {
        let groupedReviews = Dictionary(grouping: reviews, by: \.placeId)

        return places.compactMap { place in
            guard let grouped = groupedReviews[place.id], !grouped.isEmpty else {
                return nil
            }

            let total = grouped.reduce(0) { $0 + $1.ratingOverall }
            return MapPlaceAnnotation(
                id: place.id,
                place: place,
                averageRating: Double(total) / Double(grouped.count),
                reviewCount: grouped.count
            )
        }
        .sorted { $0.averageRating > $1.averageRating }
    }
}
