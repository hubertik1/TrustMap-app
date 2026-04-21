import Foundation
import OSLog

@MainActor
final class PlacesViewModel: ObservableObject {
    static let defaultFilterState = MapFilterState(selectedCategory: .all)

    @Published private(set) var placeItems: [PlaceListItem] = []
    @Published private(set) var availableCategoryOptions: [PlaceCategoryOption] = [.all]
    @Published private(set) var filterState = defaultFilterState
    @Published var searchText = ""
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

    var visiblePlaceItems: [PlaceListItem] {
        let normalizedQuery = searchText.normalizedSearchText
        guard !normalizedQuery.isEmpty else {
            return placeItems
        }

        return placeItems.filter { item in
            searchableText(for: item).contains(normalizedQuery)
        }
    }

    var hasSearchText: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func load() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            async let categories = categoryRepository.fetchMyCategories()
            async let places = mapRepository.fetchMapPlaces(
                categoryID: filterState.selectedCategory.categoryID,
                take: 250
            )
            let resolvedCategories = try await categories
            let resolvedPlaces = try await places

            availableCategoryOptions = [.all] + resolvedCategories.map(PlaceCategoryOption.init(category:))
            if filterState.selectedCategory != .all,
               !availableCategoryOptions.contains(filterState.selectedCategory) {
                filterState.selectedCategory = .all
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
                    return lhs.place.displayName.localizedStandardCompare(rhs.place.displayName) == .orderedAscending
                }

                return lhs.averageRating > rhs.averageRating
            }
            applyLocalFilters()
            errorMessage = nil
        } catch {
            guard !Self.isCancellation(error) else { return }
            logger.error("Unable to load places: \(error.localizedDescription, privacy: .public)")
            errorMessage = AppError.wrap(error).errorDescription
            allPlaceItems = []
            placeItems = []
        }
    }

    func applyFilters(_ nextFilterState: MapFilterState) async {
        let categoryChanged = filterState.selectedCategory != nextFilterState.selectedCategory

        guard filterState != nextFilterState else {
            return
        }

        filterState = nextFilterState

        if categoryChanged {
            await load()
        } else {
            applyLocalFilters()
        }
    }

    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }

    private func applyLocalFilters() {
        let currentUserID = sessionStore.currentUser?.id

        placeItems = allPlaceItems.filter { item in
            let matchesOwnership: Bool
            switch filterState.selectedOwnershipFilter {
            case .all:
                matchesOwnership = true
            case .mine:
                matchesOwnership = item.createdByUserId == currentUserID
            }

            guard matchesOwnership else {
                return false
            }

            return filterState.ratingRange.contains(Int(round(item.averageRating)))
        }
    }

    private func searchableText(for item: PlaceListItem) -> String {
        [item.place.displayName, item.place.name, item.place.address]
            .joined(separator: " ")
            .normalizedSearchText
    }
}

private extension String {
    var normalizedSearchText: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }
}
