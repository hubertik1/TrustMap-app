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

struct MapFilterState: Equatable, Sendable {
    static let defaultState = Self()

    var minimumRating: Int = 1
    var maximumRating: Int = 5
    var selectedCategory = PlaceCategoryOption.restaurant
    var selectedOwnershipFilter: PlaceOwnershipFilter = .all

    var ratingRange: ClosedRange<Int> {
        minimumRating...maximumRating
    }

    var summaryText: String {
        if minimumRating == 1 && maximumRating == 5 && selectedCategory == .all && selectedOwnershipFilter == .all {
            return "All visible places"
        }

        if minimumRating == 1 && maximumRating == 5 && selectedOwnershipFilter == .all {
            return selectedCategory.title
        }

        if minimumRating == 1 && maximumRating == 5 && selectedCategory == .all {
            return selectedOwnershipFilter.title
        }

        if selectedCategory == .all && selectedOwnershipFilter == .all {
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

        return components.joined(separator: ", ")
    }
}
