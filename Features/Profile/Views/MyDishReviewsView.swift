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
                    title: "No reviewed dishes yet",
                    message: "Dishes you review will appear here.",
                    systemImage: "fork.knife.circle.fill",
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
        .navigationTitle("Reviewed Dishes")
    }

    private var reviewsContent: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                MyDishReviewsSearchField(
                    text: $searchText,
                    placeholder: "Search reviewed dishes"
                )

                if filteredReviews.isEmpty {
                    MyDishReviewsFilteredEmptyState(
                        title: "No matching dishes",
                        message: "Try a different search.",
                        onClearSearch: {
                            searchText = ""
                        }
                    )
                    .padding(.top, 10)
                } else {
                    ForEach(filteredReviews, id: \.id) { review in
                        MyDishReviewCard(
                            review: review,
                            placeName: placeDisplayName(for: review),
                            onEdit: {
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
            AddDishReviewView(
                container: container,
                place: review.place,
                existingReview: review,
                showsCancelButton: false
            )
        }
    }

    private var filteredReviews: [DishReview] {
        let query = searchText.myDishReviewsNormalizedSearchText
        guard !query.isEmpty else {
            return reviews
        }

        return reviews.filter { review in
            searchableText(for: review).contains(query)
        }
    }

    private func placeDisplayName(for review: DishReview) -> String {
        let displayName = review.place.displayName.myDishReviewsTrimmedNonEmptyText
        let fallbackName = placeNames[review.placeId]?.myDishReviewsTrimmedNonEmptyText
        return displayName ?? fallbackName ?? "Place"
    }

    private func searchableText(for review: DishReview) -> String {
        [
            review.dishName,
            review.place.displayName,
            placeNames[review.placeId],
            review.dishReviewText,
            review.categoryName,
            formattedPriceText(for: review)
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        .myDishReviewsNormalizedSearchText
    }

    private func formattedPriceText(for review: DishReview) -> String? {
        guard let price = review.price else {
            return nil
        }

        return price.formatted(.currency(code: currencyCode(for: review)))
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
                        PhotoAsset(url: "/uploads/reviews/sample-dish-1.jpg"),
                        PhotoAsset(url: "/uploads/reviews/sample-dish-2.jpg"),
                        PhotoAsset(url: "/uploads/reviews/sample-dish-3.jpg")
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

private struct MyDishReviewCard: View {
    let review: DishReview
    let placeName: String
    let onEdit: () -> Void

    private var reviewText: String? {
        review.dishReviewText.myDishReviewsTrimmedNonEmptyText
    }

    private var categoryName: String? {
        review.categoryName?.myDishReviewsTrimmedNonEmptyText
    }

    private var price: Double? {
        review.price
    }

    private var extraPhotos: [PhotoAsset] {
        Array(review.photos.dropFirst().prefix(2))
    }

    var body: some View {
        HStack(spacing: 8) {
            leadingVisual

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    content

                    RatingBadgeView(rating: Double(review.dishRating))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    onEdit()
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilitySummary)
                .accessibilityHint("Opens edit review")

                if !extraPhotos.isEmpty {
                    PhotoGridView(
                        assets: extraPhotos,
                        presentationAssets: review.photos,
                        allowsFullscreenPresentation: true,
                        thumbnailSize: PlaceDetailVisualSystem.Metrics.inlinePhotoThumbnailSize,
                        cornerRadius: PlaceDetailVisualSystem.Metrics.photoCornerRadius,
                        spacing: PlaceDetailVisualSystem.Metrics.photoSpacing
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            tapAffordance
                .onTapGesture {
                    onEdit()
                }
                .accessibilityHidden(true)
        }
        .accessibilityAction {
            onEdit()
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(uiColor: .separator).opacity(0.12), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var leadingVisual: some View {
        if let primaryPhoto = review.photos.first {
            PhotoGridView(
                assets: [primaryPhoto],
                presentationAssets: review.photos,
                allowsFullscreenPresentation: true,
                thumbnailSize: CGSize(width: 56, height: 56),
                cornerRadius: PlaceDetailVisualSystem.Metrics.photoCornerRadius,
                spacing: PlaceDetailVisualSystem.Metrics.photoSpacing
            )
            .frame(width: 56, height: 64, alignment: .top)
        } else {
            placeholder
                .onTapGesture {
                    onEdit()
                }
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Opens edit review")
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(PlaceDetailVisualSystem.Colors.placeholderFill)
            .frame(width: 56, height: 56)
            .overlay {
                Image(systemName: "fork.knife")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(PlaceDetailVisualSystem.Colors.placeholderAccent)
                    .accessibilityHidden(true)
            }
            .accessibilityLabel("No dish photo")
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(review.dishName)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(placeName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(metadataText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.86)

            if let categoryName {
                PlaceCategoryChipView(name: categoryName)
                    .padding(.top, 1)
            }

            if let reviewText {
                Text(reviewText)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }

            if let price {
                Text(price, format: .currency(code: currencyCode(for: review)))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tapAffordance: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.bold))
            .foregroundStyle(.secondary)
            .frame(width: 28, height: 28)
    }

    private var metadataText: String {
        "Updated \(review.updatedAt.myDishReviewsCompactTimestampTextWithAgo) · \(review.visibility.myDishReviewsCompactLabel)"
    }

    private var accessibilitySummary: String {
        "\(review.dishName), \(placeName), rating \(RatingDisplayFormatter.rating(review.dishRating)), \(metadataText)"
    }
}

private struct MyDishReviewsSearchField: View {
    @Binding var text: String
    let placeholder: String

    private var hasText: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .accessibilityLabel(placeholder)

            if hasText {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(uiColor: .separator).opacity(0.12), lineWidth: 1)
        }
    }
}

private struct MyDishReviewsFilteredEmptyState: View {
    let title: String
    let message: String
    let onClearSearch: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(Color(uiColor: .tertiarySystemFill))
                )
                .accessibilityHidden(true)

            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Clear Search", action: onClearSearch)
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.bordered)
                .accessibilityLabel("Clear Search")
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(uiColor: .separator).opacity(0.12), lineWidth: 1)
        }
    }
}

private func currencyCode(for review: DishReview) -> String {
    review.currencyCode ?? Locale.current.currency?.identifier ?? "USD"
}

private extension String {
    var myDishReviewsNormalizedSearchText: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }

    var myDishReviewsTrimmedNonEmptyText: String? {
        let trimmedText = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedText.isEmpty ? nil : trimmedText
    }
}

private extension Date {
    var myDishReviewsCompactTimestampTextWithAgo: String {
        let elapsedSeconds = max(0, Int(Date.now.timeIntervalSince(self)))
        if elapsedSeconds < 60 {
            return "just now"
        }

        let minutes = elapsedSeconds / 60
        if minutes < 60 {
            return "\(minutes) min ago"
        }

        let hours = minutes / 60
        if hours < 24 {
            return "\(hours) h ago"
        }

        let days = hours / 24
        return "\(days) d ago"
    }
}

private extension VisibilityStatus {
    var myDishReviewsCompactLabel: String {
        switch self {
        case .friendsOnly:
            return "Friends"
        case .onlyMe:
            return "Private"
        case .public:
            return "Public"
        }
    }
}
