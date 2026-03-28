import SwiftUI

struct DishReviewRowView: View {
    let review: DishReview
    let authorName: String
    let photo: PhotoAsset?
    let imageDataProvider: (PhotoAsset) -> Data?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let photo, let data = imageDataProvider(photo), let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .frame(width: 64, height: 64)
                    .overlay(Image(systemName: "fork.knife").foregroundStyle(.secondary))
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
                    Text(price, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
