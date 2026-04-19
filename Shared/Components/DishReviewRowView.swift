import SwiftUI

struct DishReviewRowView: View {
    let review: DishReview
    let authorName: String
    let photo: PhotoAsset?
    var isEditable = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let photo {
                RemotePhotoView(
                    asset: photo,
                    preferredVariant: .thumbnail,
                    placeholderSystemImage: "fork.knife",
                    targetDisplaySize: CGSize(width: 64, height: 64)
                )
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

            if isEditable {
                VStack {
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                    Spacer(minLength: 0)
                }
            }
        }
        .contentShape(Rectangle())
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(.secondarySystemBackground))
            .frame(width: 64, height: 64)
            .overlay(Image(systemName: "fork.knife").foregroundStyle(.secondary))
    }
}
