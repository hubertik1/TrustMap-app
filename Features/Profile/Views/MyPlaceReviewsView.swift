import SwiftUI

struct MyPlaceReviewsView: View {
    @ObservedObject private var container: AppContainer
    let reviews: [PlaceReview]
    let placeNames: [UUID: String]
    let onDelete: @MainActor (PlaceReview) async throws -> Void

    @State private var searchText = ""
    @State private var reviewBeingEdited: PlaceReview?

    init(
        container: AppContainer,
        reviews: [PlaceReview],
        placeNames: [UUID: String],
        onDelete: @escaping @MainActor (PlaceReview) async throws -> Void
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
                    title: "No rated places yet",
                    message: "Places you review will appear here.",
                    systemImage: "mappin.and.ellipse",
                    primaryActionTitle: "Add Review",
                    onPrimaryAction: {
                        container.selectedTab = .add
                    }
                )
            } else {
                reviewsContent
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Rated Places")
    }

    private var reviewsContent: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ProfileReviewsSearchField(
                    text: $searchText,
                    placeholder: "Search rated places"
                )

                if filteredReviews.isEmpty {
                    ProfileReviewsFilteredEmptyState(
                        title: "No matching rated places",
                        message: "Try a different search.",
                        onClearSearch: {
                            searchText = ""
                        }
                    )
                    .padding(.top, 10)
                } else {
                    ForEach(filteredReviews, id: \.id) { review in
                        ProfilePlaceReviewCard(
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
            .padding(.bottom, 132)
        }
        .scrollDismissesKeyboard(.immediately)
        .navigationDestination(item: $reviewBeingEdited) { review in
            AddPlaceReviewView(
                container: container,
                place: review.place,
                existingReview: review,
                showsCancelButton: false
            )
        }
    }

    private var filteredReviews: [PlaceReview] {
        let query = searchText.profileReviewsNormalizedSearchText
        guard !query.isEmpty else {
            return reviews
        }

        return reviews.filter { review in
            searchableText(for: review).contains(query)
        }
    }

    private func placeDisplayName(for review: PlaceReview) -> String {
        let displayName = review.place.displayName.profileReviewsTrimmedNonEmptyText
        let fallbackName = placeNames[review.placeId]?.profileReviewsTrimmedNonEmptyText
        return displayName ?? fallbackName ?? "Place"
    }

    private func searchableText(for review: PlaceReview) -> String {
        [
            review.place.displayName,
            placeNames[review.placeId],
            review.place.address,
            review.place.city,
            review.place.countryCode,
            review.categoryName,
            review.reviewText,
            review.descriptionText
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        .profileReviewsNormalizedSearchText
    }
}

#Preview {
    NavigationStack {
        MyPlaceReviewsView(
            container: PreviewAppFactory.makeContainer(),
            reviews: [
                PlaceReview(
                    placeId: UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!,
                    categoryName: "Cafes",
                    visibility: .friendsOnly,
                    ratingOverall: 4,
                    reviewText: "Reliable coffee stop",
                    descriptionText: "Great coffee, quick service, and plenty of seating.",
                    updatedAt: Date().addingTimeInterval(-7_200),
                    author: PreviewAppFactory.sampleUser.summary,
                    place: Place(
                        id: UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!,
                        name: "Caffe Aurora",
                        displayName: "Caffe Aurora",
                        latitude: 37.7764,
                        longitude: -122.4231,
                        address: "123 Valencia St, San Francisco, CA",
                        city: "San Francisco",
                        countryCode: "US",
                        categoryNames: ["Cafes"]
                    ),
                    photos: [
                        PhotoAsset(url: "/uploads/reviews/sample-place-1.jpg"),
                        PhotoAsset(url: "/uploads/reviews/sample-place-2.jpg"),
                        PhotoAsset(url: "/uploads/reviews/sample-place-3.jpg")
                    ]
                ),
                PlaceReview(
                    placeId: UUID(uuidString: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE")!,
                    categoryName: nil,
                    visibility: .onlyMe,
                    ratingOverall: 3,
                    reviewText: "",
                    descriptionText: "",
                    updatedAt: Date().addingTimeInterval(-86_400 * 3),
                    author: PreviewAppFactory.sampleUser.summary,
                    place: Place(
                        id: UUID(uuidString: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE")!,
                        name: "Pocket Park",
                        displayName: "Pocket Park",
                        latitude: 37.7764,
                        longitude: -122.4231,
                        address: "",
                        city: nil,
                        countryCode: nil
                    ),
                    photos: []
                )
            ],
            placeNames: [
                UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!: "Caffè Aurora",
                UUID(uuidString: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE")!: "Pocket Park"
            ],
            onDelete: { _ in }
        )
    }
}
