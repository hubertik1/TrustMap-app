import Foundation

@MainActor
final class PlaceSearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var results: [PlaceSearchResult] = []
    @Published var isSearching = false
    @Published var errorMessage: String?

    private let sessionStore: SessionStore
    private let mapSearchService: MapSearchService
    private let placeRepository: PlaceRepository

    init(
        sessionStore: SessionStore,
        mapSearchService: MapSearchService,
        placeRepository: PlaceRepository
    ) {
        self.sessionStore = sessionStore
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

    func select(_ result: PlaceSearchResult) throws -> Place {
        guard let currentUser = sessionStore.currentUser else {
            throw AppError.missingCurrentUser
        }

        return try placeRepository.upsertPlace(from: result, createdByUserID: currentUser.id)
    }
}
