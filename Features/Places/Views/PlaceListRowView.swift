import SwiftUI

struct PlaceListRowView: View {
    let item: PlaceListItem
    var currentUserID: UUID? = nil

    private enum Metrics {
        static let trailingAccessorySpacing: CGFloat = 8
    }

    var body: some View {
        HStack(spacing: Metrics.trailingAccessorySpacing) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.place.displayName)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        if let secondaryDisplayText = item.place.secondaryDisplayText {
                            Text(secondaryDisplayText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .layoutPriority(1)

                    Spacer(minLength: 10)

                    reviewMeta
                }

                if !item.categoryNames.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(item.categoryNames, id: \.self) { name in
                            PlaceCategoryChipView(name: name)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if hasContributorSummary {
                    ContributorSummaryRow(
                        contributors: item.recentContributors,
                        totalContributorCount: item.contributorCount,
                        currentUserID: currentUserID
                    )
                    .allowsHitTesting(false)
                }
            }

            tapAffordance
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(rowBackground)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var reviewMeta: some View {
        VStack(alignment: .trailing, spacing: 4) {
            RatingBadgeView(rating: item.averageRating)

            if !hasContributorSummary {
                Text("\(item.reviewCount) review\(item.reviewCount == 1 ? "" : "s")")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(minWidth: 72, alignment: .trailing)
        .padding(.top, 1)
    }

    private var hasContributorSummary: Bool {
        !item.recentContributors.isEmpty
    }

    private var tapAffordance: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.bold))
            .foregroundStyle(.secondary)
            .frame(width: 28, height: 28)
            .accessibilityHidden(true)
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color(uiColor: .secondarySystemGroupedBackground))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color(uiColor: .separator).opacity(0.12), lineWidth: 1)
            }
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
            contributorCount: 0,
            recentContributors: [],
            latestActivityAtUtc: .now,
            categoryNames: [],
            reviewerRatings: [],
            createdByUserId: nil,
            isReviewedByCurrentUser: false,
            searchText: ""
        )
    )
    .padding()
}
