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
                MyReviewsSearchField(
                    text: $searchText,
                    placeholder: "Search rated places"
                )

                if filteredReviews.isEmpty {
                    MyReviewsFilteredEmptyState(
                        title: "No matching rated places",
                        message: "Try a different search.",
                        onClearSearch: {
                            searchText = ""
                        }
                    )
                    .padding(.top, 10)
                } else {
                    ForEach(filteredReviews, id: \.id) { review in
                        MyPlaceReviewCard(
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
            AddPlaceReviewView(
                container: container,
                place: review.place,
                existingReview: review,
                showsCancelButton: false
            )
        }
    }

    private var filteredReviews: [PlaceReview] {
        let query = searchText.myReviewsNormalizedSearchText
        guard !query.isEmpty else {
            return reviews
        }

        return reviews.filter { review in
            searchableText(for: review).contains(query)
        }
    }

    private func placeDisplayName(for review: PlaceReview) -> String {
        let displayName = review.place.displayName.myReviewsTrimmedNonEmptyText
        let fallbackName = placeNames[review.placeId]?.myReviewsTrimmedNonEmptyText
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
        .myReviewsNormalizedSearchText
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

private struct MyPlaceReviewCard: View {
    let review: PlaceReview
    let placeName: String
    let onEdit: () -> Void

    private var categoryName: String? {
        review.categoryName?.myReviewsTrimmedNonEmptyText
            ?? review.place.categoryNames.first?.myReviewsTrimmedNonEmptyText
    }

    private var addressText: String? {
        review.place.subtitle.myReviewsTrimmedNonEmptyText
    }

    private var titleText: String? {
        review.reviewText.myReviewsTrimmedNonEmptyText
    }

    private var bodyText: String? {
        review.descriptionText.myReviewsTrimmedNonEmptyText
    }

    private var previewPhotos: [PhotoAsset] {
        Array(review.photos.prefix(2))
    }

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 9) {
                    header
                    details
                    reviewText
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    onEdit()
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilitySummary)
                .accessibilityHint("Opens edit review")

                if !previewPhotos.isEmpty {
                    PhotoGridView(
                        assets: previewPhotos,
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

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(placeName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(metadataText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            RatingBadgeView(rating: Double(review.ratingOverall))
        }
    }

    @ViewBuilder
    private var details: some View {
        VStack(alignment: .leading, spacing: 7) {
            if let categoryName {
                PlaceCategoryChipView(name: categoryName)
            }

            if let addressText {
                Text(addressText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var reviewText: some View {
        if titleText != nil || bodyText != nil {
            VStack(alignment: .leading, spacing: 5) {
                if let titleText {
                    Text(titleText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let bodyText {
                    Text(bodyText)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var tapAffordance: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.bold))
            .foregroundStyle(.secondary)
            .frame(width: 28, height: 28)
    }

    private var metadataText: String {
        "Updated \(review.updatedAt.myReviewsCompactTimestampTextWithAgo) · \(review.visibility.myReviewsCompactLabel)"
    }

    private var accessibilitySummary: String {
        "\(placeName), rating \(RatingDisplayFormatter.rating(review.ratingOverall)), \(metadataText)"
    }
}

private struct MyReviewsSearchField: View {
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

private struct MyReviewsFilteredEmptyState: View {
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

private extension String {
    var myReviewsNormalizedSearchText: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }

    var myReviewsTrimmedNonEmptyText: String? {
        let trimmedText = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedText.isEmpty ? nil : trimmedText
    }
}

private extension Date {
    var myReviewsCompactTimestampTextWithAgo: String {
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
    var myReviewsCompactLabel: String {
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
