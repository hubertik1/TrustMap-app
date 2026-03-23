import SwiftUI

struct MyPlaceReviewsView: View {
    let reviews: [PlaceReview]
    let placeNames: [UUID: String]

    var body: some View {
        Group {
            if reviews.isEmpty {
                EmptyStateView(
                    title: "No Place Reviews Yet",
                    message: "Your saved place reviews will show up here.",
                    systemImage: "mappin.slash"
                )
            } else {
                List {
                    ForEach(reviews, id: \.id) { review in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(placeNames[review.placeId] ?? "Place")
                                    .font(.headline)

                                if !review.descriptionText.isEmpty {
                                    Text(review.descriptionText)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                Text(review.updatedAt, style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 12)

                            RatingBadgeView(rating: Double(review.ratingOverall))
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("My Place Reviews")
    }
}

#Preview {
    NavigationStack {
        MyPlaceReviewsView(
            reviews: [
                PlaceReview(
                    placeId: UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!,
                    authorUserId: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
                    ratingOverall: 9,
                    reviewText: "",
                    descriptionText: "Great coffee, quick service, and plenty of seating."
                )
            ],
            placeNames: [
                UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!: "Caffè Aurora"
            ]
        )
    }
}
