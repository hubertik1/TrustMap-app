import SwiftUI

struct DishReviewRowView: View {
    let review: DishReview
    let authorName: String
    let photos: [PhotoAsset]
    var safetyRepository: SafetyRepository?
    var onEdit: (() -> Void)?
    let onAuthorTap: () -> Void

    var body: some View {
        PlaceDetailReviewCard(
            rating: Double(review.dishRating),
            showsChevron: onEdit != nil,
            onEdit: onEdit
        ) {
            leadingVisual
        } content: {
            VStack(alignment: .leading, spacing: PlaceDetailVisualSystem.Metrics.textSpacing) {
                ReviewEditButton(action: onEdit) {
                    Text(review.dishName)
                        .font(PlaceDetailVisualSystem.Typography.cardTitle)
                        .foregroundStyle(PlaceDetailVisualSystem.Colors.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                ReviewAuthorButton(
                    name: authorName,
                    date: review.createdAt,
                    font: PlaceDetailVisualSystem.Typography.secondary,
                    nameColor: PlaceDetailVisualSystem.Colors.secondary,
                    action: onAuthorTap
                )
            }

            if !review.dishReviewText.isEmpty {
                ReviewEditButton(action: onEdit) {
                    Text(review.dishReviewText)
                        .font(PlaceDetailVisualSystem.Typography.body)
                        .foregroundStyle(PlaceDetailVisualSystem.Colors.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if let price = review.price {
                ReviewEditButton(action: onEdit) {
                    Text(price, format: .currency(code: review.currencyCode ?? Locale.current.currency?.identifier ?? "USD"))
                        .font(PlaceDetailVisualSystem.Typography.meta)
                        .foregroundStyle(PlaceDetailVisualSystem.Colors.tertiary)
                }
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
        .modifier(ReviewReportModifier(reviewID: review.id, reviewType: "dishReview", repository: safetyRepository))
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
