import Foundation

enum PlaceOwnershipFilter: String, CaseIterable, Identifiable {
    case all
    case mine

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "Anyone"
        case .mine:
            return "Me"
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
            return "Recently Updated"
        case .highestRated:
            return "Highest Rated"
        case .lowestRated:
            return "Lowest Rated"
        case .mostReviewed:
            return "Most Reviewed"
        case .leastReviewed:
            return "Least Reviewed"
        case .alphabetical:
            return "A-Z"
        }
    }
}

struct MapFilterState: Equatable, Sendable {
    static let defaultState = Self()

    var minimumRating: Int = 1
    var maximumRating: Int = 5
    var selectedCategory = PlaceCategoryOption.restaurants
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
            return "All visible places"
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
            return "Rating \(minimumRating)-\(maximumRating)/5"
        }

        var components: [String] = []
        if selectedCategory != .all {
            components.append(selectedCategory.title)
        }
        if selectedOwnershipFilter != .all {
            components.append(selectedOwnershipFilter.title)
        }
        if minimumRating != 1 || maximumRating != 5 {
            components.append("Rating \(minimumRating)-\(maximumRating)/5")
        }
        if selectedSortOption != .recentlyUpdated {
            components.append(selectedSortOption.title)
        }

        return components.joined(separator: ", ")
    }
}
