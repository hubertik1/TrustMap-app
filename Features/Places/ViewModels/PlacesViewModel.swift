import Foundation
import OSLog

@MainActor
final class PlacesViewModel: ObservableObject {
    @Published private(set) var placeItems: [PlaceListItem] = []
    @Published private(set) var availableCategoryOptions: [PlaceCategoryOption] = [.all]
    @Published private(set) var selectedCategory = PlaceCategoryOption.all
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let logger = Logger(subsystem: "TrustMap", category: "PlacesViewModel")
    private let mapRepository: MapRepository
    private let categoryRepository: CategoryRepository

    init(mapRepository: MapRepository, categoryRepository: CategoryRepository) {
        self.mapRepository = mapRepository
        self.categoryRepository = categoryRepository
    }

    func load() async {
        errorMessage = nil
        isLoading = true

        do {
            async let categories = categoryRepository.fetchMyCategories()
            async let places = mapRepository.fetchMapPlaces(
                categoryID: selectedCategory.categoryID,
                take: 250
            )
            let resolvedCategories = try await categories
            let resolvedPlaces = try await places

            availableCategoryOptions = [.all] + resolvedCategories.map(PlaceCategoryOption.init(category:))
            if selectedCategory != .all,
               !availableCategoryOptions.contains(selectedCategory) {
                selectedCategory = .all
            }

            placeItems = resolvedPlaces.map {
                PlaceListItem(
                    id: $0.placeId,
                    place: $0.place,
                    averageRating: $0.averagePlaceRating ?? 0,
                    reviewCount: $0.visiblePlaceReviewCount + $0.visibleDishReviewCount,
                    categoryNames: $0.categoryNames,
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

    func selectCategory(_ option: PlaceCategoryOption) async {
        guard selectedCategory != option else {
            return
        }

        selectedCategory = option
        await load()
    }
}
