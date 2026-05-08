import Foundation

struct UserStats: Equatable, Sendable {
    let ratedPlacesCount: Int
    let reviewedDishesCount: Int
}

struct ProfileStatDisplay: Equatable, Sendable {
    let title: String
    let value: String
    let isPrivate: Bool

    static func friends(count: Int, canViewFriends: Bool) -> ProfileStatDisplay {
        ProfileStatDisplay(
            title: "Friends",
            value: canViewFriends ? count.formatted() : "Private",
            isPrivate: !canViewFriends
        )
    }

    static func places(count: Int, canViewReviews: Bool) -> ProfileStatDisplay {
        ProfileStatDisplay(
            title: "Places",
            value: canViewReviews ? count.formatted() : "Private",
            isPrivate: !canViewReviews
        )
    }

    static func dishes(count: Int, canViewReviews: Bool) -> ProfileStatDisplay {
        ProfileStatDisplay(
            title: "Dishes",
            value: canViewReviews ? count.formatted() : "Private",
            isPrivate: !canViewReviews
        )
    }
}

enum ProfileReviewPrivacyContent {
    static let title = "Reviews are private"
    static let message = "This user doesn’t allow you to view their rated places or reviewed dishes."
}
