import SwiftUI

struct PlaceListRowView: View {
    let item: PlaceListItem

    var body: some View {
        HStack(spacing: 14) {
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
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(item.categoryNames, id: \.self) { name in
                                categoryChip(name)
                            }
                        }
                    }
                }
            }

            tapAffordance
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(rowBackground)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var reviewMeta: some View {
        VStack(alignment: .trailing, spacing: 4) {
            RatingBadgeView(rating: item.averageRating)

            Text("\(item.reviewCount) review\(item.reviewCount == 1 ? "" : "s")")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(minWidth: 72, alignment: .trailing)
        .padding(.top, 1)
    }

    private var tapAffordance: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.bold))
            .foregroundStyle(.secondary)
            .frame(width: 28, height: 28)
            .background(
                Circle()
                    .fill(Color(uiColor: .systemBackground).opacity(0.9))
            )
            .overlay {
                Circle()
                    .stroke(Color(uiColor: .separator).opacity(0.18), lineWidth: 1)
            }
            .accessibilityHidden(true)
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color(uiColor: .secondarySystemGroupedBackground))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(uiColor: .separator).opacity(0.12), lineWidth: 1)
            }
    }

    private func categoryChip(_ name: String) -> some View {
        Text(name)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(uiColor: .systemBackground).opacity(0.72))
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(Color(uiColor: .separator), lineWidth: 1)
                    }
            )
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
            reviewerRatings: [],
            createdByUserId: nil
        )
    )
    .padding()
}
