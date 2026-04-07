import Foundation

struct MapFilterState: Equatable, Sendable {
    var minimumRating: Int = 1
    var maximumRating: Int = 5

    var ratingRange: ClosedRange<Int> {
        minimumRating...maximumRating
    }

    var summaryText: String {
        if minimumRating == 1 && maximumRating == 5 {
            return "All visible places"
        }

        return "Rating \(minimumRating)-\(maximumRating)/5"
    }
}
