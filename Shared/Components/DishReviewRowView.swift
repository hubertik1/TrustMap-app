import SwiftUI

struct DishReviewRowView: View {
    let review: DishReview
    let authorName: String
    let photo: PhotoAsset?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let photo {
                RemotePhotoView(asset: photo, placeholderSystemImage: "fork.knife")
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                placeholder
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(review.dishName)
                        .font(.headline)

                    Spacer()

                    RatingBadgeView(rating: Double(review.dishRating))
                }

                Text(authorName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if !review.dishReviewText.isEmpty {
                    Text(review.dishReviewText)
                        .font(.subheadline)
                }

                if let price = review.price {
                    Text(price, format: .currency(code: review.currencyCode ?? Locale.current.currency?.identifier ?? "USD"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(.secondarySystemBackground))
            .frame(width: 64, height: 64)
            .overlay(Image(systemName: "fork.knife").foregroundStyle(.secondary))
    }
}
