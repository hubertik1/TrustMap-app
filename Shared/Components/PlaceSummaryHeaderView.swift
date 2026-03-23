import SwiftUI

struct PlaceSummaryHeaderView: View {
    let place: Place
    let averageRating: Double?
    let categoryNames: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(place.name)
                        .font(.title2.weight(.semibold))

                    Text(place.address)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let averageRating {
                    RatingBadgeView(rating: averageRating)
                }
            }

            if !categoryNames.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(categoryNames, id: \.self) { name in
                            Text(name)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(.secondarySystemBackground), in: Capsule())
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}
