import SwiftUI

struct ReviewCardView: View {
    let review: PlaceReview
    let authorName: String
    let photos: [PhotoAsset]
    let imageDataProvider: (PhotoAsset) -> Data?

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

            PhotoGridView(assets: photos, imageDataProvider: imageDataProvider)

            Text(review.updatedAt, style: .relative)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
