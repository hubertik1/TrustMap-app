import CoreLocation
import Foundation
import MapKit

@MainActor
final class PlaceSearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var results: [PlaceSearchResult] = []
    @Published var isSearching = false
    @Published var errorMessage: String?

    private let mapSearchService: MapSearchService
    private let placeRepository: PlaceRepository
    private let userLocationService: UserLocationServicing
    private var searchTask: Task<Void, Never>?

    init(
        mapSearchService: MapSearchService,
        placeRepository: PlaceRepository,
        userLocationService: UserLocationServicing
    ) {
        self.mapSearchService = mapSearchService
        self.placeRepository = placeRepository
        self.userLocationService = userLocationService

        if matchesAuthorizedLocationState(userLocationService.authorizationStatus),
           userLocationService.currentLocation == nil {
            userLocationService.requestCurrentLocation()
        }
    }

    deinit {
        searchTask?.cancel()
    }

    func search() async {
        await performSearch(reportErrors: true)
    }

    func handleSearchTextChange() {
        searchTask?.cancel()

        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else {
            results = []
            errorMessage = nil
            return
        }

        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            await self?.performSearch(reportErrors: false)
        }
    }

    private func performSearch(reportErrors: Bool) async {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else {
            results = []
            errorMessage = nil
            isSearching = false
            return
        }

        isSearching = true
        if reportErrors {
            errorMessage = nil
        }
        defer { isSearching = false }

        do {
            if matchesAuthorizedLocationState(userLocationService.authorizationStatus),
               userLocationService.currentLocation == nil {
                userLocationService.requestCurrentLocation()
            }

            results = try await mapSearchService.search(
                query: normalizedQuery,
                region: searchRegion
            )
            errorMessage = nil
        } catch {
            if Self.isCancellation(error) {
                return
            }

            if reportErrors {
                errorMessage = AppError.wrap(error).errorDescription
            }
        }
    }

    func select(_ result: PlaceSearchResult) async throws -> Place {
        let resolved = try await mapSearchService.resolve(result, region: nil)
        return try await placeRepository.createOrGetPlace(from: resolved)
    }

    private var searchRegion: MKCoordinateRegion? {
        guard let location = userLocationService.currentLocation else {
            return nil
        }

        return MKCoordinateRegion(
            center: location.coordinate,
            span: Self.defaultSearchSpan
        )
    }

    private static let defaultSearchSpan = MKCoordinateSpan(
        latitudeDelta: 0.2,
        longitudeDelta: 0.2
    )

    private func matchesAuthorizedLocationState(_ status: CLAuthorizationStatus) -> Bool {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        default:
            return false
        }
    }

    private static func isCancellation(_ error: Error) -> Bool {
        error is CancellationError
    }
}
