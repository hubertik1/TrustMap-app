import SwiftUI

struct ReviewCardView: View {
    let review: PlaceReview
    let authorName: String
    let photos: [PhotoAsset]
    var isEditable = false

    var body: some View {
        PlaceDetailReviewCard(
            rating: Double(review.ratingOverall),
            showsChevron: isEditable
        ) {
            AvatarView(
                name: authorName,
                size: PlaceDetailVisualSystem.Metrics.leadingVisualSize
            )
        } content: {
            VStack(alignment: .leading, spacing: PlaceDetailVisualSystem.Metrics.textSpacing) {
                Text(authorName)
                    .font(PlaceDetailVisualSystem.Typography.cardTitle)
                    .foregroundStyle(PlaceDetailVisualSystem.Colors.primary)

                Text(review.createdAt.placeDetailTimestampText)
                    .font(PlaceDetailVisualSystem.Typography.meta)
                    .foregroundStyle(PlaceDetailVisualSystem.Colors.tertiary)
            }

            if !review.reviewText.isEmpty {
                Text(review.reviewText)
                    .font(PlaceDetailVisualSystem.Typography.secondary)
                    .foregroundStyle(PlaceDetailVisualSystem.Colors.secondary)
            }

            if !review.descriptionText.isEmpty {
                Text(review.descriptionText)
                    .font(PlaceDetailVisualSystem.Typography.body)
                    .foregroundStyle(PlaceDetailVisualSystem.Colors.primary)
            }

            if !photos.isEmpty {
                PhotoGridView(
                    assets: photos,
                    allowsFullscreenPresentation: true,
                    thumbnailSize: CGSize(
                        width: PlaceDetailVisualSystem.Metrics.leadingVisualSize,
                        height: PlaceDetailVisualSystem.Metrics.leadingVisualSize
                    ),
                    cornerRadius: PlaceDetailVisualSystem.Metrics.photoCornerRadius,
                    spacing: PlaceDetailVisualSystem.Metrics.photoSpacing
                )
            }
        }
    }
}
