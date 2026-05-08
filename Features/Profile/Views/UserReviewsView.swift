import SwiftUI

struct PrivateProfileSectionView: View {
    let title: String
    let message: String

    static var reviews: PrivateProfileSectionView {
        PrivateProfileSectionView(
            title: ProfileReviewPrivacyContent.title,
            message: ProfileReviewPrivacyContent.message
        )
    }

    var body: some View {
        EmptyStateView(
            title: title,
            message: message,
            systemImage: "lock.fill"
        )
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct UserReviewsView: View {
    enum ContentMode {
        case places
        case dishes

        var navigationTitle: String {
            switch self {
            case .places:
                return "Rated Places"
            case .dishes:
                return "Reviewed Dishes"
            }
        }

        func emptyTitle(for user: User) -> String {
            switch self {
            case .places:
                return "No rated places yet."
            case .dishes:
                return "No reviewed dishes yet."
            }
        }

        func emptyMessage(for user: User) -> String {
            switch self {
            case .places:
                return "\(user.displayName) has not rated any places yet."
            case .dishes:
                return "\(user.displayName) has not reviewed any dishes yet."
            }
        }

        var emptySystemImage: String {
            switch self {
            case .places:
                return "mappin.slash"
            case .dishes:
                return "fork.knife.circle"
            }
        }
    }

    let user: User
    let placeReviews: [PlaceReview]
    let dishReviews: [DishReview]
    let placeNames: [UUID: String]
    let mode: ContentMode

    var body: some View {
        Group {
            if !user.canViewReviews {
                PrivateProfileSectionView.reviews
            } else if isEmpty {
                EmptyStateView(
                    title: mode.emptyTitle(for: user),
                    message: mode.emptyMessage(for: user),
                    systemImage: mode.emptySystemImage
                )
            } else {
                reviewsContent
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(user.canViewReviews ? mode.navigationTitle : ProfileReviewPrivacyContent.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var isEmpty: Bool {
        switch mode {
        case .places:
            return placeReviews.isEmpty
        case .dishes:
            return dishReviews.isEmpty
        }
    }

    private var reviewsContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                switch mode {
                case .places:
                    ForEach(placeReviews, id: \.id) { review in
                        ProfilePlaceReviewCard(
                            review: review,
                            placeName: placeDisplayName(for: review),
                            showsChevron: false,
                            onTap: nil
                        )
                    }

                case .dishes:
                    ForEach(dishReviews, id: \.id) { review in
                        ProfileDishReviewCard(
                            review: review,
                            placeName: placeDisplayName(for: review),
                            showsChevron: false,
                            onTap: nil
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 132)
        }
    }

    private func placeDisplayName(for review: PlaceReview) -> String {
        let displayName = review.place.displayName.profileReviewsTrimmedNonEmptyText
        let fallbackName = placeNames[review.placeId]?.profileReviewsTrimmedNonEmptyText
        return displayName ?? fallbackName ?? "Place"
    }

    private func placeDisplayName(for review: DishReview) -> String {
        let displayName = review.place.displayName.profileReviewsTrimmedNonEmptyText
        let fallbackName = placeNames[review.placeId]?.profileReviewsTrimmedNonEmptyText
        return displayName ?? fallbackName ?? "Place"
    }
}

#Preview {
    NavigationStack {
        UserReviewsView(
            user: PreviewAppFactory.sampleUser,
            placeReviews: [],
            dishReviews: [],
            placeNames: [:],
            mode: .places
        )
    }
}
