import Foundation

@MainActor
final class PlaceSearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var results: [PlaceSearchResult] = []
    @Published var isSearching = false
    @Published var errorMessage: String?

    private let mapSearchService: MapSearchService
    private let placeRepository: PlaceRepository

    init(
        mapSearchService: MapSearchService,
        placeRepository: PlaceRepository
    ) {
        self.mapSearchService = mapSearchService
        self.placeRepository = placeRepository
    }

    func search() async {
        isSearching = true
        errorMessage = nil

        do {
            results = try await mapSearchService.search(query: query, region: nil)
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
        }

        isSearching = false
    }

    func select(_ result: PlaceSearchResult) async throws -> Place {
        let resolved = try await mapSearchService.resolve(result, region: nil)
        return try await placeRepository.createOrGetPlace(from: resolved)
    }
}
