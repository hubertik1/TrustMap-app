import SwiftUI

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
                return "No visible rated places"
            case .dishes:
                return "No visible reviewed dishes"
            }
        }

        func emptyMessage(for user: User) -> String {
            switch self {
            case .places:
                return "\(user.displayName) does not have visible rated places yet."
            case .dishes:
                return "\(user.displayName) does not have visible reviewed dishes yet."
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
            if isEmpty {
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
        .navigationTitle(mode.navigationTitle)
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
