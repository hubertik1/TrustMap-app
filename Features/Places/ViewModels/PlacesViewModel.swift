import Foundation
import OSLog

@MainActor
final class PlacesViewModel: ObservableObject {
    @Published private(set) var placeItems: [PlaceListItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let logger = Logger(subsystem: "TrustMap", category: "PlacesViewModel")
    private let mapRepository: MapRepository

    init(mapRepository: MapRepository) {
        self.mapRepository = mapRepository
    }

    func load() async {
        errorMessage = nil
        isLoading = true

        do {
            let places = try await mapRepository.fetchMapPlaces(take: 250)
            placeItems = places.map {
                PlaceListItem(
                    id: $0.placeId,
                    place: $0.place,
                    averageRating: $0.averagePlaceRating ?? 0,
                    reviewCount: $0.visiblePlaceReviewCount + $0.visibleDishReviewCount,
                    categoryNames: [],
                    reviewerRatings: []
                )
            }
            .sorted { lhs, rhs in
                if lhs.averageRating == rhs.averageRating {
                    return lhs.place.name.localizedStandardCompare(rhs.place.name) == .orderedAscending
                }

                return lhs.averageRating > rhs.averageRating
            }
        } catch {
            logger.error("Unable to load places: \(error.localizedDescription, privacy: .public)")
            errorMessage = AppError.wrap(error).errorDescription
            placeItems = []
        }

        isLoading = false
    }
}
