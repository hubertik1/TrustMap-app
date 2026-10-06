import SwiftUI

struct ReviewCardView: View {
    let review: PlaceReview
    let authorName: String
    let authorAvatarURL: URL?
    let photos: [PhotoAsset]
    var safetyRepository: SafetyRepository?
    var onEdit: (() -> Void)?
    let onAuthorTap: () -> Void

    var body: some View {
        PlaceDetailReviewCard(
            rating: Double(review.ratingOverall),
            showsChevron: onEdit != nil,
            onEdit: onEdit
        ) {
            ReviewEditButton(action: onEdit) {
                AvatarView(
                    name: authorName,
                    avatarURL: authorAvatarURL,
                    size: PlaceDetailVisualSystem.Metrics.leadingVisualSize
                )
            }
        } content: {
            ReviewAuthorButton(
                name: authorName,
                date: review.createdAt,
                font: PlaceDetailVisualSystem.Typography.cardTitle,
                nameColor: PlaceDetailVisualSystem.Colors.primary,
                action: onAuthorTap
            )

            if !review.reviewText.isEmpty || !review.descriptionText.isEmpty {
                ReviewEditButton(action: onEdit) {
                    VStack(alignment: .leading, spacing: PlaceDetailVisualSystem.Metrics.contentSpacing) {
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
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if !photos.isEmpty {
                PhotoGridView(
                    assets: photos,
                    allowsFullscreenPresentation: true,
                    thumbnailSize: PlaceDetailVisualSystem.Metrics.inlinePhotoThumbnailSize,
                    cornerRadius: PlaceDetailVisualSystem.Metrics.photoCornerRadius,
                    spacing: PlaceDetailVisualSystem.Metrics.photoSpacing
                )
            }
        }
        .modifier(ReviewReportModifier(reviewID: review.id, reviewType: "placeReview", repository: safetyRepository))
    }
}
