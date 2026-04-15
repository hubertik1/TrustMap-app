import Foundation
import OSLog

@MainActor
final class PlacesViewModel: ObservableObject {
    @Published private(set) var placeItems: [PlaceListItem] = []
    @Published private(set) var availableCategoryOptions: [PlaceCategoryOption] = [.all]
    @Published private(set) var selectedCategory = PlaceCategoryOption.all
    @Published private(set) var selectedOwnershipFilter: PlaceOwnershipFilter = .all
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let logger = Logger(subsystem: "TrustMap", category: "PlacesViewModel")
    private let mapRepository: MapRepository
    private let categoryRepository: CategoryRepository
    private let sessionStore: SessionStore
    private var allPlaceItems: [PlaceListItem] = []

    init(
        mapRepository: MapRepository,
        categoryRepository: CategoryRepository,
        sessionStore: SessionStore
    ) {
        self.mapRepository = mapRepository
        self.categoryRepository = categoryRepository
        self.sessionStore = sessionStore
    }

    func load() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

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

            allPlaceItems = resolvedPlaces.map {
                PlaceListItem(
                    id: $0.placeId,
                    place: $0.place,
                    averageRating: $0.averagePlaceRating ?? 0,
                    reviewCount: $0.visiblePlaceReviewCount + $0.visibleDishReviewCount,
                    categoryNames: $0.categoryNames,
                    reviewerRatings: [],
                    createdByUserId: $0.createdByUserId
                )
            }
            .sorted { lhs, rhs in
                if lhs.averageRating == rhs.averageRating {
                    return lhs.place.name.localizedStandardCompare(rhs.place.name) == .orderedAscending
                }

                return lhs.averageRating > rhs.averageRating
            }
            applyOwnershipFilter()
            errorMessage = nil
        } catch {
            guard !Self.isCancellation(error) else { return }
            logger.error("Unable to load places: \(error.localizedDescription, privacy: .public)")
            errorMessage = AppError.wrap(error).errorDescription
            allPlaceItems = []
            placeItems = []
        }
    }

    func applyFilters(
        category option: PlaceCategoryOption,
        ownershipFilter: PlaceOwnershipFilter
    ) async {
        let categoryChanged = selectedCategory != option
        let ownershipChanged = selectedOwnershipFilter != ownershipFilter

        guard categoryChanged || ownershipChanged else {
            return
        }

        selectedCategory = option
        selectedOwnershipFilter = ownershipFilter

        if categoryChanged {
            await load()
        } else {
            applyOwnershipFilter()
        }
    }

    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }

    private func applyOwnershipFilter() {
        guard selectedOwnershipFilter == .mine else {
            placeItems = allPlaceItems
            return
        }

        guard let currentUserID = sessionStore.currentUser?.id else {
            placeItems = []
            return
        }

        placeItems = allPlaceItems.filter { $0.createdByUserId == currentUserID }
    }
}
