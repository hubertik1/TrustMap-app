import SwiftUI

struct MyDishReviewsView: View {
    @ObservedObject private var container: AppContainer
    let reviews: [DishReview]
    let placeNames: [UUID: String]
    let onDelete: @MainActor (DishReview) async throws -> Void

    @State private var searchText = ""
    @State private var reviewBeingEdited: DishReview?

    init(
        container: AppContainer,
        reviews: [DishReview],
        placeNames: [UUID: String],
        onDelete: @escaping @MainActor (DishReview) async throws -> Void
    ) {
        self.container = container
        self.reviews = reviews
        self.placeNames = placeNames
        self.onDelete = onDelete
    }

    var body: some View {
        Group {
            if reviews.isEmpty {
                ProductEmptyStateView(
                    title: L10n.noReviewedDishesYet,
                    message: L10n.dishesYouReviewWillAppearHere,
                    systemImage: "fork.knife.circle.fill",
                    primaryActionTitle: L10n.addReview,
                    onPrimaryAction: {
                        container.selectedTab = .add
                    }
                )
            } else {
                reviewsContent
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(L10n.reviewedDishes)
    }

    private var reviewsContent: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ProfileReviewsSearchField(
                    text: $searchText,
                    placeholder: L10n.searchReviewedDishes
                )

                if filteredReviews.isEmpty {
                    ProfileReviewsFilteredEmptyState(
                        title: L10n.noMatchingDishes,
                        message: L10n.tryADifferentSearch,
                        onClearSearch: {
                            searchText = ""
                        }
                    )
                    .padding(.top, 10)
                } else {
                    ForEach(filteredReviews, id: \.id) { review in
                        ProfileDishReviewCard(
                            review: review,
                            placeName: placeDisplayName(for: review),
                            showsChevron: true,
                            onTap: {
                                reviewBeingEdited = review
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, TrustMapLayout.tabAwareBottomPadding)
            .trustMapReadableContent(maxWidth: TrustMapLayout.activityContentMaxWidth, alignment: .topLeading)
        }
        .scrollDismissesKeyboard(.immediately)
        .navigationDestination(item: $reviewBeingEdited) { review in
            AddDishReviewView(
                container: container,
                place: review.place,
                existingReview: review,
                showsCancelButton: false
            )
        }
    }

    private var filteredReviews: [DishReview] {
        let query = searchText.profileReviewsNormalizedSearchText
        guard !query.isEmpty else {
            return reviews
        }

        return reviews.filter { review in
            searchableText(for: review).contains(query)
        }
    }

    private func placeDisplayName(for review: DishReview) -> String {
        let displayName = review.place.displayName.profileReviewsTrimmedNonEmptyText
        let fallbackName = placeNames[review.placeId]?.profileReviewsTrimmedNonEmptyText
        return displayName ?? fallbackName ?? L10n.place
    }

    private func searchableText(for review: DishReview) -> String {
        [
            review.dishName,
            review.place.displayName,
            placeNames[review.placeId],
            review.dishReviewText,
            review.categoryName,
            profileReviewsFormattedPriceText(for: review)
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        .profileReviewsNormalizedSearchText
    }

    private func profileReviewsFormattedPriceText(for review: DishReview) -> String? {
        guard let price = review.price else {
            return nil
        }

        return price.formatted(.currency(code: profileReviewsCurrencyCode(for: review)))
    }
}

#Preview {
    NavigationStack {
        MyDishReviewsView(
            container: PreviewAppFactory.makeContainer(),
            reviews: [
                DishReview(
                    placeId: UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!,
                    categoryName: "Restaurants",
                    visibility: .friendsOnly,
                    dishName: "Tiramisu Pancakes",
                    dishRating: 4,
                    dishReviewText: "Ridiculously good mascarpone cream.",
                    priceAmount: 14,
                    currencyCode: "USD",
                    updatedAt: Date().addingTimeInterval(-86_400 * 7),
                    author: PreviewAppFactory.sampleUser.summary,
                    place: Place(
                        id: UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!,
                        name: "Caffe Aurora",
                        displayName: "Caffe Aurora",
                        latitude: 37.7764,
                        longitude: -122.4231,
                        address: "123 Valencia St, San Francisco, CA",
                        city: "San Francisco",
                        countryCode: "US"
                    ),
                    photos: [
                        PhotoAsset(url: "/media/photos/20000000-0000-4000-8000-000000000001"),
                        PhotoAsset(url: "/media/photos/20000000-0000-4000-8000-000000000002"),
                        PhotoAsset(url: "/media/photos/20000000-0000-4000-8000-000000000003")
                    ]
                ),
                DishReview(
                    placeId: UUID(uuidString: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE")!,
                    categoryName: "Restaurants",
                    visibility: .onlyMe,
                    dishName: "Hot Dog",
                    dishRating: 3,
                    dishReviewText: "",
                    priceAmount: nil,
                    currencyCode: nil,
                    updatedAt: Date().addingTimeInterval(-3_600),
                    author: PreviewAppFactory.sampleUser.summary,
                    place: Place(
                        id: UUID(uuidString: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE")!,
                        name: "IKEA",
                        displayName: "IKEA",
                        latitude: 37.7764,
                        longitude: -122.4231,
                        address: "1 Market St",
                        city: "San Francisco",
                        countryCode: "US"
                    ),
                    photos: []
                )
            ],
            placeNames: [
                UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!: "Caffè Aurora",
                UUID(uuidString: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE")!: "IKEA"
            ],
            onDelete: { _ in }
        )
    }
}
