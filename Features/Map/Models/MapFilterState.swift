import Foundation

struct MapFilterState: Equatable, Sendable {
    var minimumRating: Int = 1
    var maximumRating: Int = 5
    var selectedCategory = PlaceCategoryOption.restaurant

    var ratingRange: ClosedRange<Int> {
        minimumRating...maximumRating
    }

    var summaryText: String {
        if minimumRating == 1 && maximumRating == 5 && selectedCategory == .all {
            return "All visible places"
        }

        if minimumRating == 1 && maximumRating == 5 {
            return selectedCategory.title
        }

        if selectedCategory == .all {
            return "Rating \(minimumRating)-\(maximumRating)/5"
        }

        return "\(selectedCategory.title), \(minimumRating)-\(maximumRating)/5"
    }
}
