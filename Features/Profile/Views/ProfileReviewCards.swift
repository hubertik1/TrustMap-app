import SwiftUI

struct ProfilePlaceReviewCard: View {
    let review: PlaceReview
    let placeName: String
    var showsChevron = true
    var onTap: (() -> Void)?

    private var categoryName: String? {
        review.categoryName?.profileReviewsTrimmedNonEmptyText
            ?? review.place.categoryNames.first?.profileReviewsTrimmedNonEmptyText
    }

    private var addressText: String? {
        review.place.subtitle.profileReviewsTrimmedNonEmptyText
    }

    private var titleText: String? {
        review.reviewText.profileReviewsTrimmedNonEmptyText
    }

    private var bodyText: String? {
        review.descriptionText.profileReviewsTrimmedNonEmptyText
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
                    onTap?()
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilitySummary)
                .accessibilityHint(onTap == nil ? "" : "Opens edit review")

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

            if showsChevron {
                tapAffordance
                    .onTapGesture {
                        onTap?()
                    }
                    .accessibilityHidden(true)
            }
        }
        .accessibilityAction {
            onTap?()
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
        "Updated \(review.updatedAt.profileReviewsCompactTimestampTextWithAgo) · \(review.visibility.profileReviewsCompactLabel)"
    }

    private var accessibilitySummary: String {
        "\(placeName), rating \(RatingDisplayFormatter.rating(review.ratingOverall)), \(metadataText)"
    }
}

struct ProfileDishReviewCard: View {
    let review: DishReview
    let placeName: String
    var showsChevron = true
    var onTap: (() -> Void)?

    private var reviewText: String? {
        review.dishReviewText.profileReviewsTrimmedNonEmptyText
    }

    private var categoryName: String? {
        review.categoryName?.profileReviewsTrimmedNonEmptyText
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
                    onTap?()
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilitySummary)
                .accessibilityHint(onTap == nil ? "" : "Opens edit review")

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

            if showsChevron {
                tapAffordance
                    .onTapGesture {
                        onTap?()
                    }
                    .accessibilityHidden(true)
            }
        }
        .accessibilityAction {
            onTap?()
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
                    onTap?()
                }
                .accessibilityHint(onTap == nil ? "" : "Opens edit review")
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
                Text(price, format: .currency(code: profileReviewsCurrencyCode(for: review)))
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
        "Updated \(review.updatedAt.profileReviewsCompactTimestampTextWithAgo) · \(review.visibility.profileReviewsCompactLabel)"
    }

    private var accessibilitySummary: String {
        "\(review.dishName), \(placeName), rating \(RatingDisplayFormatter.rating(review.dishRating)), \(metadataText)"
    }
}

struct ProfileReviewsSearchField: View {
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

struct ProfileReviewsFilteredEmptyState: View {
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

func profileReviewsCurrencyCode(for review: DishReview) -> String {
    review.currencyCode ?? Locale.current.currency?.identifier ?? "USD"
}

extension String {
    var profileReviewsNormalizedSearchText: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }

    var profileReviewsTrimmedNonEmptyText: String? {
        let trimmedText = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedText.isEmpty ? nil : trimmedText
    }
}

extension Date {
    var profileReviewsCompactTimestampTextWithAgo: String {
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

extension VisibilityStatus {
    var profileReviewsCompactLabel: String {
        switch self {
        case .friendsOnly:
            return "Friends"
        case .friendsOfFriends:
            return "Friends of Friends"
        case .onlyMe:
            return "Private"
        case .public:
            return "Everyone"
        }
    }
}
