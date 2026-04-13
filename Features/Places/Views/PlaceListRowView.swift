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
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(Color(.tertiarySystemBackground))
                                        .overlay {
                                            Capsule(style: .continuous)
                                                .stroke(Color(.separator).opacity(0.35), lineWidth: 1)
                                        }
                                )
                        }
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
            categoryNames: [],
            reviewerRatings: []
        )
    )
    .padding()
}
