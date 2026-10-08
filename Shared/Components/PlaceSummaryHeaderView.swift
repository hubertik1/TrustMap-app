import SwiftUI

struct PlaceSummaryHeaderView<Accessory: View>: View {
    let place: Place
    let averageRating: Double?
    let categoryNames: [String]
    var contributors: [UserSummary] = []
    var contributorCount = 0
    var currentUserID: UUID? = nil
    private let showsAccessory: Bool
    private let accessory: Accessory

    init(
        place: Place,
        averageRating: Double?,
        categoryNames: [String],
        contributors: [UserSummary] = [],
        contributorCount: Int = 0,
        currentUserID: UUID? = nil,
        showsAccessory: Bool = true,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.place = place
        self.averageRating = averageRating
        self.categoryNames = categoryNames
        self.contributors = contributors
        self.contributorCount = contributorCount
        self.currentUserID = currentUserID
        self.showsAccessory = showsAccessory
        self.accessory = accessory()
    }

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

            if showsAccessory {
                accessory
                    .padding(.top, 6)
            }
        }
        .padding(.vertical, 4)
    }
}

extension PlaceSummaryHeaderView where Accessory == EmptyView {
    init(
        place: Place,
        averageRating: Double?,
        categoryNames: [String],
        contributors: [UserSummary] = [],
        contributorCount: Int = 0,
        currentUserID: UUID? = nil
    ) {
        self.init(
            place: place,
            averageRating: averageRating,
            categoryNames: categoryNames,
            contributors: contributors,
            contributorCount: contributorCount,
            currentUserID: currentUserID,
            showsAccessory: false
        ) {
            EmptyView()
        }
    }
}

struct PlaceCategoryChipView: View {
    let name: String

    var body: some View {
        Text(DefaultCategoryCatalog.displayName(for: name))
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
