import SwiftUI

struct PlaceSummaryHeaderView: View {
    let place: Place
    let averageRating: Double?
    let categoryNames: [String]
    var contributors: [UserSummary] = []
    var contributorCount = 0
    var currentUserID: UUID? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(place.displayName)
                        .font(PlaceDetailVisualSystem.Typography.summaryTitle)
                        .foregroundStyle(PlaceDetailVisualSystem.Colors.primary)

                    if let secondaryDisplayText = place.secondaryDisplayText {
                        Text(secondaryDisplayText)
                            .font(PlaceDetailVisualSystem.Typography.secondary)
                            .foregroundStyle(PlaceDetailVisualSystem.Colors.secondary)
                    }

                    if !categoryNames.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(categoryNames, id: \.self) { name in
                                PlaceCategoryChipView(name: name)
                            }
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 2)
                    }

                    if !contributors.isEmpty {
                        ContributorSummaryRow(
                            contributors: contributors,
                            totalContributorCount: contributorCount,
                            currentUserID: currentUserID
                        )
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

struct PlaceCategoryChipView: View {
    let name: String

    var body: some View {
        Text(name)
            .font(PlaceDetailVisualSystem.Typography.chip)
            .foregroundStyle(PlaceDetailVisualSystem.Colors.secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .overlay {
                Capsule()
                    .strokeBorder(PlaceDetailVisualSystem.Colors.secondary, lineWidth: 1)
            }
    }
}
