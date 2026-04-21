import SwiftUI

struct ReviewCardView: View {
    let review: PlaceReview
    let authorName: String
    let photos: [PhotoAsset]

    var body: some View {
        VStack(alignment: .leading, spacing: hasExtendedContent ? 10 : 8) {
            HStack(alignment: .top, spacing: 10) {
                AvatarView(name: authorName, size: hasExtendedContent ? 40 : 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text(authorName)
                        .font(.subheadline.weight(.semibold))

                    Text(review.createdAt.placeReviewTimestampText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                RatingBadgeView(rating: Double(review.ratingOverall))
                    .padding(.top, 1)
            }

            if !review.reviewText.isEmpty {
                Text(review.reviewText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            if !review.descriptionText.isEmpty {
                Text(review.descriptionText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !photos.isEmpty {
                PhotoGridView(assets: photos, allowsFullscreenPresentation: true)
            }
        }
        .padding(hasExtendedContent ? 14 : 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(.separator).opacity(0.35), lineWidth: 1)
                }
        )
    }

    private var hasExtendedContent: Bool {
        !review.reviewText.isEmpty || !review.descriptionText.isEmpty || !photos.isEmpty
    }
}

private extension Date {
    var placeReviewTimestampText: String {
        let elapsedSeconds = max(0, Int(Date.now.timeIntervalSince(self)))
        let minutes = elapsedSeconds / 60

        if minutes < 60 {
            return "\(minutes) min"
        }

        let hours = minutes / 60
        if hours < 24 {
            return "\(hours) h"
        }

        let days = hours / 24
        return "\(days) d"
    }
}
