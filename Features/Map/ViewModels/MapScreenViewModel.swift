import CoreLocation
import Foundation
import MapKit

@MainActor
final class MapScreenViewModel: ObservableObject {
    @Published var region: MKCoordinateRegion?
    @Published var requestedCameraRegion: MKCoordinateRegion?
    @Published var searchText = ""
    @Published var searchResults: [PlaceSearchResult] = []
    @Published var annotations: [MapPlaceAnnotation] = []
    @Published var availablePeople: [FilterPerson] = []
    @Published var filterState = MapFilterState()
    @Published var selectedPlace: Place?
    @Published var promptPlace: Place?
    @Published var droppedPinPlace: Place?
    @Published var placeForReview: Place?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isFilterPresented = false
    @Published private(set) var locationAccessState: UserLocationAccessState = .idle

    private let sessionStore: SessionStore
    private let friendRepository: FriendRepository
    private let userRepository: UserProfileRepository
    private let placeRepository: PlaceRepository
    private let placeReviewRepository: PlaceReviewRepository
    private let mapSearchService: MapSearchService
    private let userLocationService: UserLocationServicing
    private var hasCenteredOnUserLocation = false
    private var hasStartedLocationFlow = false
    private var shouldCenterOnNextLocationUpdate = true
    private var searchTask: Task<Void, Never>?

    init(
        sessionStore: SessionStore,
        friendRepository: FriendRepository,
        userRepository: UserProfileRepository,
        placeRepository: PlaceRepository,
        placeReviewRepository: PlaceReviewRepository,
        mapSearchService: MapSearchService,
        userLocationService: UserLocationServicing
    ) {
        self.sessionStore = sessionStore
        self.friendRepository = friendRepository
        self.userRepository = userRepository
        self.placeRepository = placeRepository
        self.placeReviewRepository = placeReviewRepository
        self.mapSearchService = mapSearchService
        self.userLocationService = userLocationService

        self.userLocationService.onAuthorizationChange = { [weak self] status in
            self?.handleAuthorizationChange(status)
        }
        self.userLocationService.onLocationUpdate = { [weak self] location in
            self?.handleLocationUpdate(location)
        }
        self.userLocationService.onError = { [weak self] error in
            self?.handleLocationError(error)
        }
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
        await searchForSuggestions(reportErrors: true)
    }

    func applyFilters() async {
        await load()
    }

    func handleSearchTextChange() {
        searchTask?.cancel()

        let normalizedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else {
            searchResults = []
            return
        }

        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else {
                return
            }

            await self?.searchForSuggestions(reportErrors: false)
        }
    }

    func startLocationFlowIfNeeded() {
        guard !hasStartedLocationFlow else {
            return
        }

        hasStartedLocationFlow = true
        locationAccessState = userLocationService.authorizationStatus == .notDetermined ? .requestingPermission : .locating
        userLocationService.start()
    }

    func recenterOnUserLocation() {
        locationAccessState = .locating
        shouldCenterOnNextLocationUpdate = true
        userLocationService.requestCurrentLocation()
    }

    func selectAnnotation(_ annotation: MapPlaceAnnotation) {
        promptPlace = annotation.place
    }

    func selectPlace(withID placeID: UUID) {
        guard let annotation = annotations.first(where: { $0.place.id == placeID }) else {
            return
        }

        droppedPinPlace = nil
        promptPlace = annotation.place
        focus(on: annotation.place.coordinate)
    }

    func selectSearchResult(_ result: PlaceSearchResult) async {
        guard let currentUser = sessionStore.currentUser else {
            errorMessage = AppError.missingCurrentUser.errorDescription
            return
        }

        do {
            let resolvedResult = try await mapSearchService.resolve(result, region: region)
            let place = try placeRepository.upsertPlace(from: resolvedResult, createdByUserID: currentUser.id)
            searchResults = []
            searchText = ""
            let searchRegion = MKCoordinateRegion(
                center: resolvedResult.coordinate ?? region?.center ?? CLLocationCoordinate2D(latitude: 52.2297, longitude: 21.0122),
                span: Self.defaultSpan
            )
            region = searchRegion
            requestedCameraRegion = searchRegion
            droppedPinPlace = nil
            promptPlace = place
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
        }
    }

    func selectMapLocation(at coordinate: CLLocationCoordinate2D) async {
        guard let currentUser = sessionStore.currentUser else {
            errorMessage = AppError.missingCurrentUser.errorDescription
            return
        }

        do {
            let resolvedResult = try await mapSearchService.resolveMapTap(at: coordinate)
            let place = try placeRepository.upsertPlace(from: resolvedResult, createdByUserID: currentUser.id)
            promptPlace = place
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
        }
    }

    func selectLongPressLocation(at coordinate: CLLocationCoordinate2D) async {
        guard let currentUser = sessionStore.currentUser else {
            errorMessage = AppError.missingCurrentUser.errorDescription
            return
        }

        do {
            let resolvedResult = try await mapSearchService.resolveDroppedPin(at: coordinate)
            let place = try placeRepository.upsertPlace(from: resolvedResult, createdByUserID: currentUser.id)
            droppedPinPlace = place
            promptPlace = place
            focus(on: coordinate)
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
        }
    }

    func selectMapFeature(title: String?, coordinate: CLLocationCoordinate2D) async {
        guard let currentUser = sessionStore.currentUser else {
            errorMessage = AppError.missingCurrentUser.errorDescription
            return
        }

        do {
            let resolvedResult = try await mapSearchService.resolveFeature(
                title: title,
                coordinate: coordinate,
                region: region
            )
            let place = try placeRepository.upsertPlace(from: resolvedResult, createdByUserID: currentUser.id)
            droppedPinPlace = nil
            promptPlace = place
            focus(on: coordinate)
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
        }
    }

    func openPromptedPlaceDetails() {
        guard let promptPlace else {
            return
        }

        droppedPinPlace = nil
        selectedPlace = promptPlace
        self.promptPlace = nil
    }

    func startReviewForPromptedPlace() {
        guard let promptPlace else {
            return
        }

        droppedPinPlace = nil
        placeForReview = promptPlace
        self.promptPlace = nil
    }

    func dismissPrompt() {
        droppedPinPlace = nil
        promptPlace = nil
    }

    private func focus(on coordinate: CLLocationCoordinate2D) {
        let span = region?.span ?? Self.defaultSpan
        requestedCameraRegion = MKCoordinateRegion(center: coordinate, span: span)
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

    private func handleAuthorizationChange(_ status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            locationAccessState = .requestingPermission
        case .authorizedAlways, .authorizedWhenInUse:
            locationAccessState = .locating
        case .denied:
            locationAccessState = .denied
        case .restricted:
            locationAccessState = .restricted
        @unknown default:
            locationAccessState = .failed("TrustMap could not read the current location permission status.")
        }
    }

    private func handleLocationUpdate(_ location: CLLocation) {
        locationAccessState = .ready

        let userRegion = MKCoordinateRegion(
            center: location.coordinate,
            span: Self.defaultSpan
        )
        region = userRegion

        guard shouldCenterOnNextLocationUpdate || !hasCenteredOnUserLocation else {
            return
        }

        hasCenteredOnUserLocation = true
        shouldCenterOnNextLocationUpdate = false
        requestedCameraRegion = userRegion
    }

    private func handleLocationError(_ error: AppError) {
        locationAccessState = .failed(error.errorDescription ?? "TrustMap could not determine your current location.")
    }

    private func searchForSuggestions(reportErrors: Bool) async {
        let normalizedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else {
            searchResults = []
            return
        }

        do {
            searchResults = try await mapSearchService.search(query: normalizedQuery, region: region)
            if reportErrors {
                errorMessage = nil
            }
        } catch {
            searchResults = []
            if reportErrors {
                errorMessage = AppError.wrap(error).errorDescription
            }
        }
    }
}

private extension MapScreenViewModel {
    static let defaultSpan = MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
}
