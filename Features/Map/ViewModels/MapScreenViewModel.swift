import CoreLocation
import Foundation
import MapKit
import OSLog

@MainActor
final class MapScreenViewModel: ObservableObject {
    struct PromptContext: Identifiable {
        let place: Place
        let coordinate: CLLocationCoordinate2D

        var id: UUID {
            place.id
        }
    }

    @Published var region: MKCoordinateRegion?
    @Published var requestedCameraRegion: MKCoordinateRegion?
    @Published var searchText = ""
    @Published var searchResults: [PlaceSearchResult] = []
    @Published var annotations: [MapPlaceAnnotation] = []
    @Published private(set) var availableCategoryOptions: [PlaceCategoryOption] = [.all]
    @Published var filterState = MapFilterState()
    @Published var isSatelliteEnabled = false
    @Published var selectedPlace: Place?
    @Published var selectedAnnotationID: UUID?
    @Published var promptContext: PromptContext?
    @Published var droppedPinPlace: Place?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isFilterPresented = false
    @Published private(set) var hasLoadedMapPlaces = false
    @Published private(set) var hasVisibleAnnotationsInCurrentViewport = false
    @Published private(set) var locationAccessState: UserLocationAccessState = .idle

    var requestedCameraRegionToken = UUID()

    var hasActiveFilters: Bool {
        filterState != .defaultState
    }

    private let logger = Logger(subsystem: "TrustMap", category: "MapScreenViewModel")
    private let mapRepository: MapRepository
    private let placeRepository: PlaceRepository
    private let categoryRepository: CategoryRepository
    private let mapSearchService: MapSearchService
    private let sessionStore: SessionStore
    private let userLocationService: UserLocationServicing
    private var promptPresentationTask: Task<Void, Never>?
    private var latestMapReloadRequestID = UUID()
    private var cachedPinsByPlaceId: [UUID: MapPin] = [:]
    private var loadedBounds: [MapBounds] = []
    private var mapReloadTask: Task<Void, Never>?
    private var hasStartedLocationFlow = false
    private var shouldCenterOnNextLocationUpdate = true
    private var searchTask: Task<Void, Never>?

    init(
        mapRepository: MapRepository,
        placeRepository: PlaceRepository,
        categoryRepository: CategoryRepository,
        mapSearchService: MapSearchService,
        sessionStore: SessionStore,
        userLocationService: UserLocationServicing,
        preferencesStore: AppPreferencesStore
    ) {
        self.mapRepository = mapRepository
        self.placeRepository = placeRepository
        self.categoryRepository = categoryRepository
        self.mapSearchService = mapSearchService
        self.sessionStore = sessionStore
        self.userLocationService = userLocationService
        self.isSatelliteEnabled = preferencesStore.defaultMapStyle == .satellite
        self.shouldCenterOnNextLocationUpdate = preferencesStore.centerOnUserLocationOnLaunch

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
        promptPresentationTask?.cancel()
        mapReloadTask?.cancel()
    }

    func load(resetPinCache: Bool = false) async {
        errorMessage = nil
        isLoading = true
        await loadCategories()

        if resetPinCache {
            clearPinCache()
        }

        await reloadMapPinsForCurrentRegion(force: true)
        isLoading = false
    }

    func performSearch() async {
        await searchForSuggestions(reportErrors: true)
    }

    func applyFilters() async {
        rebuildAnnotations()
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

    func selectPlace(withID placeID: UUID) async {
        if let annotation = annotations.first(where: { $0.place.id == placeID }) {
            do {
                let placeDetails = try await placeRepository.fetchPlaceDetails(id: placeID)
                droppedPinPlace = nil
                startPromptFlow(
                    for: placeDetails.place,
                    coordinate: placeDetails.place.coordinate,
                    selectedAnnotationID: annotation.id
                )
            } catch {
                logger.error("Unable to load selected map place: \(error.localizedDescription, privacy: .public)")
                errorMessage = AppError.wrap(error).errorDescription
            }
        }
    }

    func refreshPin(placeID: UUID) async {
        mapReloadTask?.cancel()
        latestMapReloadRequestID = UUID()

        do {
            if let pin = try await mapRepository.fetchMapPin(placeId: placeID) {
                cachedPinsByPlaceId[placeID] = pin
            } else {
                cachedPinsByPlaceId.removeValue(forKey: placeID)
            }

            rebuildAnnotations()
            if let region {
                scheduleMapPinsFetchIfNeeded(for: region)
            }
            errorMessage = nil
        } catch {
            if Self.isNotFoundResponse(error) {
                cachedPinsByPlaceId.removeValue(forKey: placeID)
                rebuildAnnotations()
                errorMessage = nil
                await reloadMapPinsForCurrentRegion(force: true)
                return
            }

            logger.error("Unable to refresh map pin: \(error.localizedDescription, privacy: .public)")
            await reloadMapPinsForCurrentRegion(force: true)
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
            startPromptFlow(
                for: place,
                coordinate: searchRegion.center,
                selectedAnnotationID: nil
            )
            await loadPinsIfNeeded(for: searchRegion, debounce: false)
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
        }
    }

    func selectLongPressLocation(at coordinate: CLLocationCoordinate2D) async {
        do {
            let resolvedResult = try await mapSearchService.resolveDroppedPin(at: coordinate)
            let place = try await placeRepository.createOrGetPlace(from: resolvedResult)
            droppedPinPlace = place
            startPromptFlow(for: place, coordinate: coordinate, selectedAnnotationID: nil)
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
            startPromptFlow(for: place, coordinate: coordinate, selectedAnnotationID: nil)
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
        }
    }

    func openPromptedPlaceDetails() {
        guard let promptContext else { return }
        selectedPlace = promptContext.place
        clearPromptState(keepSelectedPlace: true)
    }

    func dismissPrompt() {
        clearPromptState()
    }

    func handleCameraChangeDidEnd(_ region: MKCoordinateRegion) {
        self.region = region
        rebuildAnnotations()
        scheduleMapPinsFetchIfNeeded(for: region)
    }

    func clearRequestedCameraRegion() {
        requestedCameraRegion = nil
    }

    private func reloadMapPinsForCurrentRegion(force: Bool) async {
        guard let region else {
            if cachedPinsByPlaceId.isEmpty {
                hasLoadedMapPlaces = false
            }
            return
        }

        let viewportBounds = mapBounds(from: region)
        guard force || shouldFetchPins(for: viewportBounds) else {
            mapReloadTask?.cancel()
            mapReloadTask = nil
            latestMapReloadRequestID = UUID()
            rebuildAnnotations()
            return
        }

        mapReloadTask?.cancel()
        let requestID = UUID()
        latestMapReloadRequestID = requestID

        await fetchMapPins(
            in: expandedBounds(from: region),
            requestID: requestID
        )
    }

    private func loadPinsIfNeeded(for region: MKCoordinateRegion, debounce: Bool) async {
        let viewportBounds = mapBounds(from: region)
        guard shouldFetchPins(for: viewportBounds) else {
            mapReloadTask?.cancel()
            mapReloadTask = nil
            latestMapReloadRequestID = UUID()
            rebuildAnnotations()
            return
        }

        if debounce {
            scheduleMapPinsFetchIfNeeded(for: region)
        } else {
            mapReloadTask?.cancel()
            let requestID = UUID()
            latestMapReloadRequestID = requestID
            await fetchMapPins(
                in: expandedBounds(from: region),
                requestID: requestID
            )
        }
    }

    private func scheduleMapPinsFetchIfNeeded(for region: MKCoordinateRegion) {
        let viewportBounds = mapBounds(from: region)
        guard shouldFetchPins(for: viewportBounds) else {
            mapReloadTask?.cancel()
            mapReloadTask = nil
            latestMapReloadRequestID = UUID()
            return
        }

        let requestBounds = expandedBounds(from: region)
        let requestID = UUID()
        latestMapReloadRequestID = requestID
        mapReloadTask?.cancel()
        mapReloadTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            await self?.fetchMapPins(
                in: requestBounds,
                requestID: requestID
            )
        }
    }

    private func fetchMapPins(in requestBounds: MapBounds, requestID: UUID) async {
        isLoading = true

        do {
            let pins = try await fetchPins(in: requestBounds)

            guard latestMapReloadRequestID == requestID else {
                return
            }

            mergeFetchedPins(pins, fetchedBounds: requestBounds)
            loadedBounds = MapBoundsCoverage.appending(requestBounds, to: loadedBounds)
            rebuildAnnotations()
            hasLoadedMapPlaces = true
            errorMessage = nil
        } catch {
            guard latestMapReloadRequestID == requestID else {
                return
            }
            guard !Self.isCancellation(error) else {
                return
            }
            logger.error("Unable to load map pins: \(error.localizedDescription, privacy: .public)")
            errorMessage = AppError.wrap(error).errorDescription
        }

        if latestMapReloadRequestID == requestID {
            isLoading = false
        }
    }

    private func fetchPins(in requestBounds: MapBounds) async throws -> [MapPin] {
        do {
            return try await mapRepository.fetchMapPins(
                north: requestBounds.north,
                south: requestBounds.south,
                east: requestBounds.east,
                west: requestBounds.west
            )
        } catch {
            guard Self.isNotFoundResponse(error) else {
                throw error
            }

            logger.notice("Map pins endpoint not found. Falling back to legacy map places endpoint.")
            let places = try await mapRepository.fetchMapPlaces(
                north: requestBounds.north,
                south: requestBounds.south,
                east: requestBounds.east,
                west: requestBounds.west,
                take: 250
            )
            return makePins(fromLegacyMapPlaces: places)
        }
    }

    private func makePins(fromLegacyMapPlaces places: [MapPlace]) -> [MapPin] {
        places.map { place in
            MapPin(
                placeId: place.placeId,
                displayName: place.displayName,
                latitude: place.latitude,
                longitude: place.longitude,
                averageRating: place.averagePlaceRating,
                reviewCount: place.visiblePlaceReviewCount + place.visibleDishReviewCount,
                contributorCount: place.contributorCount,
                categoryIds: categoryIDs(for: place.categoryNames),
                isReviewedByCurrentUser: place.isReviewedByCurrentUser,
                latestActivityAtUtc: place.latestActivityAtUtc
            )
        }
    }

    private func categoryIDs(for categoryNames: [String]) -> [UUID] {
        var optionIDsByKey: [String: UUID] = [:]
        for option in availableCategoryOptions {
            guard let categoryID = option.categoryID,
                  let key = DefaultCategoryCatalog.canonicalKey(for: option.title) else {
                continue
            }

            optionIDsByKey[key] = optionIDsByKey[key] ?? categoryID
        }

        var categoryIDs: [UUID] = []
        var seenIDs = Set<UUID>()

        for categoryName in categoryNames {
            guard let key = DefaultCategoryCatalog.canonicalKey(for: categoryName),
                  let categoryID = optionIDsByKey[key],
                  seenIDs.insert(categoryID).inserted else {
                continue
            }

            categoryIDs.append(categoryID)
        }

        return categoryIDs
    }

    private func loadCategories() async {
        do {
            let categories = try await categoryRepository.fetchMyCategories()
            let options = [.all] + categories.map(PlaceCategoryOption.init(category:))
            availableCategoryOptions = options

            if !options.contains(filterState.selectedCategory) {
                filterState.selectedCategory = .all
            }
        } catch {
            logger.error("Unable to load map categories: \(error.localizedDescription, privacy: .public)")
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

    private func rebuildAnnotations() {
        let snapshot = MapPinAnnotationBuilder.makeSnapshot(
            from: cachedPinsByPlaceId.values,
            filterState: filterState,
            viewportBounds: region.map { mapBounds(from: $0) }
        )
        annotations = snapshot.annotations
        hasVisibleAnnotationsInCurrentViewport = snapshot.hasVisibleAnnotationsInCurrentViewport
    }

    private func mergeFetchedPins(_ pins: [MapPin], fetchedBounds: MapBounds) {
        let fetchedPlaceIds = Set(pins.map(\.placeId))
        for (placeID, cachedPin) in cachedPinsByPlaceId where fetchedBounds.contains(cachedPin.coordinate) && !fetchedPlaceIds.contains(placeID) {
            cachedPinsByPlaceId.removeValue(forKey: placeID)
        }

        for pin in pins {
            cachedPinsByPlaceId[pin.placeId] = pin
        }
    }

    private func clearPinCache() {
        mapReloadTask?.cancel()
        cachedPinsByPlaceId = [:]
        loadedBounds = []
        annotations = []
        hasVisibleAnnotationsInCurrentViewport = false
        hasLoadedMapPlaces = false
    }

    private func shouldFetchPins(for viewportBounds: MapBounds) -> Bool {
        MapBoundsCoverage.shouldFetchPins(for: viewportBounds, loadedBounds: loadedBounds)
    }

    private func startPromptFlow(for place: Place, coordinate: CLLocationCoordinate2D, selectedAnnotationID: UUID?) {
        promptPresentationTask?.cancel()
        promptPresentationTask = nil

        let context = PromptContext(place: place, coordinate: coordinate)

        self.selectedAnnotationID = selectedAnnotationID
        promptContext = nil

        let targetRegion = promptCameraRegion(focusedOn: coordinate)
        if let region, isRegion(region, centeredOn: targetRegion.center) {
            requestedCameraRegion = nil
            schedulePromptPresentation(for: context, delayMilliseconds: 180)
            return
        }

        region = targetRegion
        requestedCameraRegion = targetRegion
        requestedCameraRegionToken = UUID()
        rebuildAnnotations()
        scheduleMapPinsFetchIfNeeded(for: targetRegion)
        schedulePromptPresentation(for: context, delayMilliseconds: 520)
    }

    private func schedulePromptPresentation(for context: PromptContext, delayMilliseconds: Int) {
        promptPresentationTask?.cancel()
        promptPresentationTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(delayMilliseconds))
            guard let self else {
                return
            }

            self.promptContext = context
            self.promptPresentationTask = nil
        }
    }

    private func clearPromptState(keepSelectedPlace: Bool = false) {
        promptPresentationTask?.cancel()
        promptPresentationTask = nil
        promptContext = nil
        selectedAnnotationID = nil
        droppedPinPlace = nil

        if !keepSelectedPlace {
            selectedPlace = nil
        }
    }

    private func mapBounds(from region: MKCoordinateRegion) -> MapBounds {
        let halfLat = region.span.latitudeDelta / 2
        let halfLon = region.span.longitudeDelta / 2

        return MapBounds(
            north: min(90, region.center.latitude + halfLat),
            south: max(-90, region.center.latitude - halfLat),
            east: min(180, region.center.longitude + halfLon),
            west: max(-180, region.center.longitude - halfLon)
        )
    }

    private func expandedBounds(from region: MKCoordinateRegion) -> MapBounds {
        let expansionMultiplier = 2.0
        let halfLat = region.span.latitudeDelta * expansionMultiplier / 2
        let halfLon = region.span.longitudeDelta * expansionMultiplier / 2

        return MapBounds(
            north: min(90, region.center.latitude + halfLat),
            south: max(-90, region.center.latitude - halfLat),
            east: min(180, region.center.longitude + halfLon),
            west: max(-180, region.center.longitude - halfLon)
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
            locationAccessState = .failed(L10n.trustmapCouldNotDetermineLocationAccess)
        }
    }

    private func handleLocationUpdate(_ location: CLLocation) {
        locationAccessState = .ready
        guard shouldCenterOnNextLocationUpdate else {
            return
        }

        let userRegion = MKCoordinateRegion(center: location.coordinate, span: Self.defaultSpan)
        region = userRegion
        requestedCameraRegion = userRegion
        requestedCameraRegionToken = UUID()
        rebuildAnnotations()
        scheduleMapPinsFetchIfNeeded(for: userRegion)
        shouldCenterOnNextLocationUpdate = false
    }

    private func handleLocationError(_ error: AppError) {
        locationAccessState = .failed(error.errorDescription ?? L10n.trustmapCouldNotDetermineYourCurrentLocation)
    }

    private static let defaultSpan = MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)
    private static let promptVerticalFocusOffsetRatio = 0.16

    private func promptCameraRegion(focusedOn coordinate: CLLocationCoordinate2D) -> MKCoordinateRegion {
        let span = region?.span ?? Self.defaultSpan
        let shiftedCenter = CLLocationCoordinate2D(
            latitude: coordinate.latitude - span.latitudeDelta * Self.promptVerticalFocusOffsetRatio,
            longitude: coordinate.longitude
        )

        return MKCoordinateRegion(center: shiftedCenter, span: span)
    }

    private func isRegion(_ region: MKCoordinateRegion, centeredOn coordinate: CLLocationCoordinate2D) -> Bool {
        region.center.isClose(to: coordinate)
    }

    private static func isNotFoundResponse(_ error: Error) -> Bool {
        guard case .validationFailure(let message) = AppError.wrap(error) else {
            return false
        }

        return message.localizedCaseInsensitiveContains("not found")
    }

    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }
}

private extension CLLocationCoordinate2D {
    func isClose(to other: CLLocationCoordinate2D, tolerance: Double = 0.0003) -> Bool {
        abs(latitude - other.latitude) <= tolerance
            && abs(longitude - other.longitude) <= tolerance
    }
}
