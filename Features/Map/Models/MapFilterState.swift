import Foundation

enum PlaceOwnershipFilter: String, CaseIterable, Identifiable {
    case all
    case mine

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return L10n.anyone
        case .mine:
            return L10n.me
        }
    }
}

enum PlaceSortOption: String, CaseIterable, Identifiable, Sendable {
    case recentlyUpdated
    case highestRated
    case lowestRated
    case mostReviewed
    case leastReviewed
    case alphabetical

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recentlyUpdated:
            return L10n.recentlyUpdated
        case .highestRated:
            return L10n.highestRated
        case .lowestRated:
            return L10n.lowestRated
        case .mostReviewed:
            return L10n.mostReviewed
        case .leastReviewed:
            return L10n.leastReviewed
        case .alphabetical:
            return L10n.aZ
        }
    }
}

struct MapFilterState: Equatable, Sendable {
    static let defaultState = Self()

    var minimumRating: Int = 1
    var maximumRating: Int = 5
    var selectedCategory = PlaceCategoryOption.all
    var selectedOwnershipFilter: PlaceOwnershipFilter = .all
    var selectedSortOption: PlaceSortOption = .recentlyUpdated

    var ratingRange: ClosedRange<Int> {
        minimumRating...maximumRating
    }

    var summaryText: String {
        if minimumRating == 1
            && maximumRating == 5
            && selectedCategory == .all
            && selectedOwnershipFilter == .all
            && selectedSortOption == .recentlyUpdated {
            return L10n.allVisiblePlaces
        }

        if minimumRating == 1
            && maximumRating == 5
            && selectedOwnershipFilter == .all
            && selectedSortOption == .recentlyUpdated {
            return selectedCategory.title
        }

        if minimumRating == 1
            && maximumRating == 5
            && selectedCategory == .all
            && selectedSortOption == .recentlyUpdated {
            return selectedOwnershipFilter.title
        }

        if selectedCategory == .all
            && selectedOwnershipFilter == .all
            && selectedSortOption == .recentlyUpdated {
            return L10n.ratingValueValue5(String(describing: minimumRating), String(describing: maximumRating))
        }

        var components: [String] = []
        if selectedCategory != .all {
            components.append(selectedCategory.title)
        }
        if selectedOwnershipFilter != .all {
            components.append(selectedOwnershipFilter.title)
        }
        if minimumRating != 1 || maximumRating != 5 {
            components.append(L10n.ratingValueValue5(String(describing: minimumRating), String(describing: maximumRating)))
        }
        if selectedSortOption != .recentlyUpdated {
            components.append(selectedSortOption.title)
        }

        return components.joined(separator: ", ")
    }
}
