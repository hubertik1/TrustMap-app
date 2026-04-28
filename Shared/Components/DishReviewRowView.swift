import SwiftUI

struct DishReviewRowView: View {
    let review: DishReview
    let authorName: String
    let photos: [PhotoAsset]
    var isEditable = false

    var body: some View {
        PlaceDetailReviewCard(
            rating: Double(review.dishRating),
            showsChevron: isEditable
        ) {
            leadingVisual
        } content: {
            VStack(alignment: .leading, spacing: PlaceDetailVisualSystem.Metrics.textSpacing) {
                Text(review.dishName)
                    .font(PlaceDetailVisualSystem.Typography.cardTitle)
                    .foregroundStyle(PlaceDetailVisualSystem.Colors.primary)

                Text(authorName)
                    .font(PlaceDetailVisualSystem.Typography.secondary)
                    .foregroundStyle(PlaceDetailVisualSystem.Colors.secondary)

                Text(review.createdAt.placeDetailTimestampText)
                    .font(PlaceDetailVisualSystem.Typography.meta)
                    .foregroundStyle(PlaceDetailVisualSystem.Colors.tertiary)
            }

            if !review.dishReviewText.isEmpty {
                Text(review.dishReviewText)
                    .font(PlaceDetailVisualSystem.Typography.body)
                    .foregroundStyle(PlaceDetailVisualSystem.Colors.primary)
            }

            if let price = review.price {
                Text(price, format: .currency(code: review.currencyCode ?? Locale.current.currency?.identifier ?? "USD"))
                    .font(PlaceDetailVisualSystem.Typography.meta)
                    .foregroundStyle(PlaceDetailVisualSystem.Colors.tertiary)
            }

            if !trailingPhotos.isEmpty {
                PhotoGridView(
                    assets: trailingPhotos,
                    presentationAssets: photos,
                    allowsFullscreenPresentation: true,
                    thumbnailSize: PlaceDetailVisualSystem.Metrics.inlinePhotoThumbnailSize,
                    cornerRadius: PlaceDetailVisualSystem.Metrics.photoCornerRadius,
                    spacing: PlaceDetailVisualSystem.Metrics.photoSpacing
                )
            }
        }
    }

    @ViewBuilder
    private var leadingVisual: some View {
        if let primaryPhoto = photos.first {
            PhotoGridView(
                assets: [primaryPhoto],
                presentationAssets: photos,
                allowsFullscreenPresentation: true,
                thumbnailSize: CGSize(
                    width: PlaceDetailVisualSystem.Metrics.leadingVisualSize,
                    height: PlaceDetailVisualSystem.Metrics.leadingVisualSize
                ),
                cornerRadius: PlaceDetailVisualSystem.Metrics.photoCornerRadius,
                spacing: PlaceDetailVisualSystem.Metrics.photoSpacing
            )
        } else {
            placeholder
        }
    }

    private var trailingPhotos: [PhotoAsset] {
        Array(photos.dropFirst())
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(PlaceDetailVisualSystem.Colors.placeholderFill)
            .overlay {
                Image(systemName: "fork.knife")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(PlaceDetailVisualSystem.Colors.placeholderAccent)
            }
            .clipShape(
                RoundedRectangle(
                    cornerRadius: PlaceDetailVisualSystem.Metrics.photoCornerRadius,
                    style: .continuous
                )
            )
    }
}
