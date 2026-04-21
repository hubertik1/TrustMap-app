import SwiftUI

struct PlaceSummaryHeaderView: View {
    let place: Place
    let averageRating: Double?
    let categoryNames: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(place.displayName)
                        .font(.title3.weight(.semibold))

                    if let secondaryDisplayText = place.secondaryDisplayText {
                        Text(secondaryDisplayText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if !categoryNames.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(categoryNames, id: \.self) { name in
                                Text(name)
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4)
                                    .background(Color(.secondarySystemBackground), in: Capsule())
                            }
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 2)
                    }
                }

                Spacer()

                if let averageRating {
                    RatingBadgeView(rating: averageRating)
                        .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
