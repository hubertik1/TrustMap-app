import SwiftUI

struct ReviewCardView: View {
    let review: PlaceReview
    let authorName: String
    let photos: [PhotoAsset]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                AvatarView(name: authorName)

                Text(authorName)
                    .font(.headline)

                Spacer()

                RatingBadgeView(rating: Double(review.ratingOverall))
            }

            if !review.descriptionText.isEmpty {
                Text(review.descriptionText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            PhotoGridView(assets: photos)

            Text(review.createdAt.placeReviewTimestampText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(.separator).opacity(0.35), lineWidth: 1)
                }
        )
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
