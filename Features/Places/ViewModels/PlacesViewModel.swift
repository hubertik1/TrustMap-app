import CoreLocation
import Foundation
import OSLog

enum PlacesSortOption: String, CaseIterable, Identifiable, Sendable {
    case recentlyUpdated
    case highestRated
    case mostReviewed
    case nearest
    case alphabetical

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recentlyUpdated:
            return "Recently Updated"
        case .highestRated:
            return "Highest Rated"
        case .mostReviewed:
            return "Most Reviewed"
        case .nearest:
            return "Nearest"
        case .alphabetical:
            return "A-Z"
        }
    }

    static func options(isNearestAvailable: Bool) -> [Self] {
        allCases.filter { option in
            option != .nearest || isNearestAvailable
        }
    }
}

struct PlacesFilterState: Equatable, Sendable {
    static let defaultState = Self()

    var addedBy: PlaceOwnershipFilter = .all
    var selectedCategory: PlaceCategoryOption = .all
    var selectedSortOption: PlacesSortOption = .recentlyUpdated
    var minimumRating: Double?

    var isDefault: Bool {
        self == Self.defaultState
    }

    var activeFilterCount: Int {
        var count = 0

        if addedBy != .all {
            count += 1
        }

        if selectedCategory != .all {
            count += 1
        }

        if selectedSortOption != .recentlyUpdated {
            count += 1
        }

        if minimumRating != nil {
            count += 1
        }

        return count
    }
}

@MainActor
final class PlacesViewModel: ObservableObject {
    static let defaultFilterState = PlacesFilterState.defaultState

    @Published private(set) var placeItems: [PlaceListItem] = []
    @Published private(set) var availableCategoryOptions: [PlaceCategoryOption] = [.all]
    @Published private(set) var filterState = defaultFilterState
    @Published private(set) var isNearestSortAvailable = false
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let logger = Logger(subsystem: "TrustMap", category: "PlacesViewModel")
    private let mapRepository: MapRepository
    private let categoryRepository: CategoryRepository
    private let sessionStore: SessionStore
    private let userLocationService: UserLocationServicing
    private var allPlaceItems: [PlaceListItem] = []

    init(
        mapRepository: MapRepository,
        categoryRepository: CategoryRepository,
        sessionStore: SessionStore,
        userLocationService: UserLocationServicing
    ) {
        self.mapRepository = mapRepository
        self.categoryRepository = categoryRepository
        self.sessionStore = sessionStore
        self.userLocationService = userLocationService
        self.isNearestSortAvailable = userLocationService.currentLocation != nil
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

    var hasLoadedPlacesBeforeFiltering: Bool {
        !allPlaceItems.isEmpty
    }

    var shouldShowLibraryContent: Bool {
        hasLoadedPlacesBeforeFiltering || filterState.activeFilterCount > 0 || hasSearchText
    }

    var hasActiveFilters: Bool {
        filterState.activeFilterCount > 0
    }

    var activeFilterCount: Int {
        filterState.activeFilterCount
    }

    var availableSortOptions: [PlacesSortOption] {
        PlacesSortOption.options(isNearestAvailable: isNearestSortAvailable)
    }

    var filterAccessibilityLabel: String {
        let activeFilterCount = filterState.activeFilterCount
        guard activeFilterCount > 0 else {
            return "Filters"
        }

        return "Filters, \(activeFilterCount) active"
    }

    func refreshLocationAvailability() {
        let hasCurrentLocation = userLocationService.currentLocation != nil
        if isNearestSortAvailable != hasCurrentLocation {
            isNearestSortAvailable = hasCurrentLocation
        }

        if !hasCurrentLocation, filterState.selectedSortOption == .nearest {
            filterState.selectedSortOption = .recentlyUpdated
            applyLocalFilters()
        }
    }

    func draftFilterStateForEditing() -> PlacesFilterState {
        normalizedFilterState(filterState)
    }

    func load() async {
        let hadExistingContent = !allPlaceItems.isEmpty
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            refreshLocationAvailability()

            let resolvedCategories = try await categoryRepository.fetchMyCategories()
            availableCategoryOptions = [.all] + resolvedCategories.map(PlaceCategoryOption.init(category:))
            if filterState.selectedCategory != .all,
               !availableCategoryOptions.contains(filterState.selectedCategory) {
                filterState.selectedCategory = .all
            }

            let resolvedPlaces = try await mapRepository.fetchMapPlaces(
                categoryID: filterState.selectedCategory.categoryID,
                take: 250
            )

            allPlaceItems = resolvedPlaces.map {
                PlaceListItem(
                    id: $0.placeId,
                    place: $0.place,
                    averageRating: $0.averagePlaceRating ?? 0,
                    reviewCount: $0.visiblePlaceReviewCount + $0.visibleDishReviewCount,
                    contributorCount: $0.contributorCount,
                    recentContributors: $0.recentContributors,
                    latestActivityAtUtc: $0.latestActivityAtUtc,
                    categoryNames: $0.categoryNames,
                    reviewerRatings: [],
                    createdByUserId: $0.createdByUserId
                )
            }
            applyLocalFilters()
            errorMessage = nil
        } catch {
            guard !Self.isCancellation(error) else { return }
            logger.error("Unable to load places: \(error.localizedDescription, privacy: .public)")
            errorMessage = AppError.wrap(error).errorDescription
            if !hadExistingContent {
                allPlaceItems = []
                placeItems = []
            }
        }
    }

    func applyFilters(_ nextFilterState: PlacesFilterState) async {
        let normalizedNextFilterState = normalizedFilterState(nextFilterState)
        let categoryChanged = filterState.selectedCategory != normalizedNextFilterState.selectedCategory

        guard filterState != normalizedNextFilterState else {
            return
        }

        filterState = normalizedNextFilterState

        if categoryChanged {
            await load()
        } else {
            applyLocalFilters()
        }
    }

    func resetFilters() async {
        await applyFilters(Self.defaultFilterState)
    }

    func toggleMinimumRating(_ rating: Double) async {
        var nextFilterState = filterState
        nextFilterState.minimumRating = nextFilterState.minimumRating == rating ? nil : rating
        await applyFilters(nextFilterState)
    }

    func toggleMostReviewed() async {
        var nextFilterState = filterState
        nextFilterState.selectedSortOption = nextFilterState.selectedSortOption == .mostReviewed
            ? .recentlyUpdated
            : .mostReviewed
        await applyFilters(nextFilterState)
    }

    func toggleMine() async {
        var nextFilterState = filterState
        nextFilterState.addedBy = nextFilterState.addedBy == .mine ? .all : .mine
        await applyFilters(nextFilterState)
    }

    func selectNearestSort() async {
        refreshLocationAvailability()
        guard isNearestSortAvailable else {
            return
        }

        var nextFilterState = filterState
        nextFilterState.selectedSortOption = nextFilterState.selectedSortOption == .nearest
            ? .recentlyUpdated
            : .nearest
        await applyFilters(nextFilterState)
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

        let filteredItems = allPlaceItems.filter { item in
            let matchesOwnership: Bool
            switch filterState.addedBy {
            case .all:
                matchesOwnership = true
            case .mine:
                matchesOwnership = item.createdByUserId == currentUserID
            }

            guard matchesOwnership else {
                return false
            }

            if let minimumRating = filterState.minimumRating {
                return item.averageRating >= minimumRating
            }

            return true
        }

        placeItems = filteredItems.sorted(by: sortComparator)
    }

    private func sortComparator(lhs: PlaceListItem, rhs: PlaceListItem) -> Bool {
        switch filterState.selectedSortOption {
        case .recentlyUpdated:
            if lhs.latestActivityAtUtc != rhs.latestActivityAtUtc {
                return lhs.latestActivityAtUtc > rhs.latestActivityAtUtc
            }
        case .highestRated:
            if lhs.averageRating != rhs.averageRating {
                return lhs.averageRating > rhs.averageRating
            }
        case .mostReviewed:
            if lhs.reviewCount != rhs.reviewCount {
                return lhs.reviewCount > rhs.reviewCount
            }
        case .nearest:
            let currentLocation = userLocationService.currentLocation
            if currentLocation == nil,
               lhs.latestActivityAtUtc != rhs.latestActivityAtUtc {
                return lhs.latestActivityAtUtc > rhs.latestActivityAtUtc
            }

            let lhsDistance = distance(from: currentLocation, to: lhs)
            let rhsDistance = distance(from: currentLocation, to: rhs)
            if let lhsDistance, let rhsDistance, lhsDistance != rhsDistance {
                return lhsDistance < rhsDistance
            }

            if lhsDistance != nil, rhsDistance == nil {
                return true
            }

            if lhsDistance == nil, rhsDistance != nil {
                return false
            }
        case .alphabetical:
            break
        }

        return fallbackSort(lhs: lhs, rhs: rhs)
    }

    private func normalizedFilterState(_ filterState: PlacesFilterState) -> PlacesFilterState {
        var normalizedFilterState = filterState

        if normalizedFilterState.selectedSortOption == .nearest,
           userLocationService.currentLocation == nil {
            normalizedFilterState.selectedSortOption = .recentlyUpdated
        }

        if !availableCategoryOptions.contains(normalizedFilterState.selectedCategory) {
            normalizedFilterState.selectedCategory = .all
        }

        return normalizedFilterState
    }

    private func distance(from currentLocation: CLLocation?, to item: PlaceListItem) -> CLLocationDistance? {
        guard let currentLocation,
              item.place.latitude.isFinite,
              item.place.longitude.isFinite else {
            return nil
        }

        let placeLocation = CLLocation(
            latitude: item.place.latitude,
            longitude: item.place.longitude
        )

        return placeLocation.distance(from: currentLocation)
    }

    private func fallbackSort(lhs: PlaceListItem, rhs: PlaceListItem) -> Bool {
        let nameComparison = lhs.place.displayName.localizedStandardCompare(rhs.place.displayName)
        if nameComparison != .orderedSame {
            return nameComparison == .orderedAscending
        }

        return lhs.id.uuidString < rhs.id.uuidString
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
