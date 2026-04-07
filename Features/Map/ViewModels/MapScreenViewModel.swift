import CoreLocation
import Foundation
import MapKit
import OSLog

@MainActor
final class MapScreenViewModel: ObservableObject {
    @Published var region: MKCoordinateRegion?
    @Published var requestedCameraRegion: MKCoordinateRegion?
    @Published var searchText = ""
    @Published var searchResults: [PlaceSearchResult] = []
    @Published var annotations: [MapPlaceAnnotation] = []
    @Published var filterState = MapFilterState()
    @Published var isSatelliteEnabled = false
    @Published var selectedPlace: Place?
    @Published var selectedAnnotationID: UUID?
    @Published var promptPlace: Place?
    @Published var droppedPinPlace: Place?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isFilterPresented = false
    @Published private(set) var locationAccessState: UserLocationAccessState = .idle

    var requestedCameraRegionToken = UUID()

    private let logger = Logger(subsystem: "TrustMap", category: "MapScreenViewModel")
    private let mapRepository: MapRepository
    private let placeRepository: PlaceRepository
    private let mapSearchService: MapSearchService
    private let userLocationService: UserLocationServicing
    private var pendingPromptPlace: Place?
    private var pendingPromptCoordinate: CLLocationCoordinate2D?
    private var hasCenteredOnUserLocation = false
    private var hasStartedLocationFlow = false
    private var shouldCenterOnNextLocationUpdate = true
    private var searchTask: Task<Void, Never>?

    init(
        mapRepository: MapRepository,
        placeRepository: PlaceRepository,
        mapSearchService: MapSearchService,
        userLocationService: UserLocationServicing
    ) {
        self.mapRepository = mapRepository
        self.placeRepository = placeRepository
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

    deinit {
        searchTask?.cancel()
    }

    func load() async {
        errorMessage = nil
        isLoading = true
        await reloadMapPlaces()
        isLoading = false
    }

    func performSearch() async {
        await searchForSuggestions(reportErrors: true)
    }

    func applyFilters() async {
        await reloadMapPlaces()
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
            guard !Task.isCancelled else { return }
            await self?.searchForSuggestions(reportErrors: false)
        }
    }

    func startLocationFlowIfNeeded() {
        guard !hasStartedLocationFlow else { return }
        hasStartedLocationFlow = true
        locationAccessState = userLocationService.authorizationStatus == .notDetermined ? .requestingPermission : .locating
        userLocationService.start()
    }

    func recenterOnUserLocation() {
        locationAccessState = .locating
        shouldCenterOnNextLocationUpdate = true
        userLocationService.requestCurrentLocation()
    }

    func selectPlace(withID placeID: UUID) {
        if let annotation = annotations.first(where: { $0.place.id == placeID }) {
            droppedPinPlace = nil
            selectedAnnotationID = annotation.id
            deferPromptPresentation(for: annotation.place, focusingOn: annotation.place.coordinate)
        }
    }

    func selectSearchResult(_ result: PlaceSearchResult) async {
        do {
            let resolvedResult = try await mapSearchService.resolve(result, region: region)
            let place = try await placeRepository.createOrGetPlace(from: resolvedResult)
            searchResults = []
            searchText = ""
            let searchRegion = MKCoordinateRegion(
                center: resolvedResult.coordinate ?? region?.center ?? CLLocationCoordinate2D(latitude: 52.2297, longitude: 21.0122),
                span: Self.defaultSpan
            )
            region = searchRegion
            requestedCameraRegion = searchRegion
            requestedCameraRegionToken = UUID()
            droppedPinPlace = nil
            deferPromptPresentation(for: place, focusingOn: searchRegion.center)
            await reloadMapPlaces()
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
        }
    }

    func selectLongPressLocation(at coordinate: CLLocationCoordinate2D) async {
        do {
            let resolvedResult = try await mapSearchService.resolveDroppedPin(at: coordinate)
            let place = try await placeRepository.createOrGetPlace(from: resolvedResult)
            droppedPinPlace = place
            deferPromptPresentation(for: place, focusingOn: coordinate)
            await reloadMapPlaces()
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
        }
    }

    func selectMapFeature(title: String?, coordinate: CLLocationCoordinate2D) async {
        do {
            let resolvedResult = try await mapSearchService.resolveFeature(
                title: title,
                coordinate: coordinate,
                region: region
            )
            let place = try await placeRepository.createOrGetPlace(from: resolvedResult)
            droppedPinPlace = nil
            deferPromptPresentation(for: place, focusingOn: coordinate)
            await reloadMapPlaces()
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
        }
    }

    func openPromptedPlaceDetails() {
        guard let promptPlace else { return }
        selectedPlace = promptPlace
        self.promptPlace = nil
        selectedAnnotationID = nil
        pendingPromptPlace = nil
        pendingPromptCoordinate = nil
        droppedPinPlace = nil
    }

    func dismissPrompt() {
        promptPlace = nil
        selectedAnnotationID = nil
        pendingPromptPlace = nil
        pendingPromptCoordinate = nil
        droppedPinPlace = nil
    }

    func handleCameraChangeDidEnd(_ region: MKCoordinateRegion) {
        self.region = region

        if let pendingPromptPlace,
           let pendingPromptCoordinate,
           region.center.isClose(to: pendingPromptCoordinate) {
            promptPlace = pendingPromptPlace
            self.pendingPromptPlace = nil
            self.pendingPromptCoordinate = nil
        }

        Task { await reloadMapPlaces() }
    }

    func clearRequestedCameraRegion() {
        requestedCameraRegion = nil
    }

    private func reloadMapPlaces() async {
        do {
            let bounds = mapBounds(from: region)
            let places = try await mapRepository.fetchMapPlaces(
                north: bounds?.north,
                south: bounds?.south,
                east: bounds?.east,
                west: bounds?.west,
                take: 250
            )

            annotations = places
                .filter { mapPlace in
                    guard let average = mapPlace.averagePlaceRating else {
                        return filterState.minimumRating <= 1
                    }

                    return filterState.ratingRange.contains(Int(round(average)))
                }
                .map {
                    MapPlaceAnnotation(
                        id: $0.placeId,
                        place: $0.place,
                        averageRating: $0.averagePlaceRating ?? 0,
                        reviewCount: $0.visiblePlaceReviewCount + $0.visibleDishReviewCount
                    )
                }
            errorMessage = nil
        } catch {
            logger.error("Unable to load map places: \(error.localizedDescription, privacy: .public)")
            errorMessage = AppError.wrap(error).errorDescription
        }
    }

    private func searchForSuggestions(reportErrors: Bool) async {
        do {
            searchResults = try await mapSearchService.search(query: searchText, region: region)
            if reportErrors {
                errorMessage = nil
            }
        } catch {
            if reportErrors {
                errorMessage = AppError.wrap(error).errorDescription
            }
        }
    }

    private func deferPromptPresentation(for place: Place, focusingOn coordinate: CLLocationCoordinate2D) {
        let targetRegion = MKCoordinateRegion(center: coordinate, span: Self.defaultSpan)
        promptPlace = nil
        pendingPromptPlace = place
        pendingPromptCoordinate = coordinate
        region = targetRegion
        requestedCameraRegion = targetRegion
        requestedCameraRegionToken = UUID()
    }

    private func mapBounds(from region: MKCoordinateRegion?) -> (north: Double, south: Double, east: Double, west: Double)? {
        guard let region else { return nil }
        let halfLat = region.span.latitudeDelta / 2
        let halfLon = region.span.longitudeDelta / 2

        return (
            north: region.center.latitude + halfLat,
            south: region.center.latitude - halfLat,
            east: region.center.longitude + halfLon,
            west: region.center.longitude - halfLon
        )
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
            locationAccessState = .failed("TrustMap could not determine location access.")
        }
    }

    private func handleLocationUpdate(_ location: CLLocation) {
        locationAccessState = .ready
        guard !hasCenteredOnUserLocation || shouldCenterOnNextLocationUpdate else {
            return
        }

        let userRegion = MKCoordinateRegion(center: location.coordinate, span: Self.defaultSpan)
        region = userRegion
        requestedCameraRegion = userRegion
        requestedCameraRegionToken = UUID()
        hasCenteredOnUserLocation = true
        shouldCenterOnNextLocationUpdate = false
    }

    private func handleLocationError(_ error: AppError) {
        locationAccessState = .failed(error.errorDescription ?? "TrustMap could not determine your current location.")
    }

    private static let defaultSpan = MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)
}

private extension CLLocationCoordinate2D {
    func isClose(to other: CLLocationCoordinate2D, tolerance: Double = 0.0003) -> Bool {
        abs(latitude - other.latitude) <= tolerance
            && abs(longitude - other.longitude) <= tolerance
    }
}
