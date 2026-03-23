import SwiftUI

struct PlaceListRowView: View {
    let item: PlaceListItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.place.name)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(item.place.address)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    RatingBadgeView(rating: item.averageRating)
                    Text("\(item.reviewCount) review\(item.reviewCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !item.categoryNames.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(item.categoryNames, id: \.self) { name in
                            Text(name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.thinMaterial, in: Capsule())
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("People Ratings")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(item.reviewerRatings.prefix(3)) { rating in
                    HStack(spacing: 8) {
                        Text(rating.reviewerName)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)

                        Spacer()

                        Text("\(rating.rating)/10")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    if !rating.descriptionText.isEmpty {
                        Text(rating.descriptionText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    let container = PreviewAppFactory.makeContainer()
    let place = PreviewAppFactory.samplePlace(in: container)

    PlaceListRowView(
        item: PlaceListItem(
            id: place.id,
            place: place,
            averageRating: 8.7,
            reviewCount: 3,
            categoryNames: ["Restaurants", "Pizza"],
            reviewerRatings: [
                PlaceReviewerRating(id: UUID(), reviewerID: UUID(), reviewerName: "Me", rating: 9, descriptionText: "Great crust and strong pasta menu."),
                PlaceReviewerRating(id: UUID(), reviewerID: UUID(), reviewerName: "Alice", rating: 8, descriptionText: "Excellent date-night spot."),
                PlaceReviewerRating(id: UUID(), reviewerID: UUID(), reviewerName: "Bob", rating: 9, descriptionText: "Worth going back for dessert.")
            ]
        )
    )
    .padding()
}
