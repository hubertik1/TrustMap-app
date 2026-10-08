import SwiftUI

enum PlaceDetailVisualSystem {
    enum Typography {
        static let sectionTitle = Font.subheadline.weight(.semibold)
        static let summaryTitle = Font.title3.weight(.semibold)
        static let cardTitle = Font.subheadline.weight(.semibold)
        static let secondary = Font.subheadline
        static let body = Font.subheadline
        static let meta = Font.caption
        static let chip = Font.caption.weight(.medium)
    }

    enum Colors {
        static let primary = Color.primary
        static let secondary = Color(uiColor: .secondaryLabel)
        static let tertiary = Color(uiColor: .tertiaryLabel)
        static let cardFill = Color(uiColor: .secondarySystemGroupedBackground)
        static let cardStroke = Color(uiColor: .separator).opacity(0.12)
        static let placeholderFill = Color(uiColor: .secondarySystemBackground)
        static let placeholderAccent = Color.accentColor
    }

    enum Metrics {
        static let cardCornerRadius: CGFloat = 24
        static let cardPadding: CGFloat = 14
        static let columnSpacing: CGFloat = 12
        static let contentSpacing: CGFloat = 6
        static let textSpacing: CGFloat = 2
        static let leadingVisualSize: CGFloat = 52
        static let inlinePhotoThumbnailSize = CGSize(width: 72, height: 72)
        static let photoThumbnailSize = CGSize(width: 88, height: 88)
        static let photoCornerRadius: CGFloat = 14
        static let photoSpacing: CGFloat = 10
        static let ratingAccessorySpacing: CGFloat = 8
        static let chevronWidth: CGFloat = 12
        static let trailingAccessoryMinWidth: CGFloat = 52
        static let headerActionHeight: CGFloat = 44
        static let headerActionHorizontalPadding: CGFloat = 12
        static let headerActionIconSize: CGFloat = 15
        static let sectionHeaderMinHeight: CGFloat = 36
        static let sectionHeaderTitleVerticalOffset: CGFloat = 6
        static let sectionActionHeight: CGFloat = 30
        static let sectionActionHorizontalPadding: CGFloat = 12
    }
}

struct PlaceDetailSectionHeaderView: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    var count: Int? = nil
    var actionTitle: String? = nil
    var actionAccessibilityLabel: String? = nil
    var titleVerticalOffset: CGFloat = 0
    var action: (() -> Void)? = nil

    var body: some View {
        ViewThatFits(in: .horizontal) {
            horizontalHeader

            if action != nil {
                VStack(alignment: .leading, spacing: 8) {
                    titleCountLabel
                    actionButton
                }
            } else {
                titleCountLabel
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .offset(y: titleVerticalOffset)
        .textCase(nil)
    }

    private var horizontalHeader: some View {
        HStack(alignment: .center, spacing: 8) {
            titleCountLabel

            Spacer(minLength: 12)

            actionButton
        }
        .frame(minHeight: PlaceDetailVisualSystem.Metrics.sectionHeaderMinHeight, alignment: .center)
    }

    private var titleCountLabel: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(PlaceDetailVisualSystem.Typography.sectionTitle)
                .foregroundStyle(PlaceDetailVisualSystem.Colors.secondary)

            if let count {
                Text("\(count)")
                    .font(PlaceDetailVisualSystem.Typography.sectionTitle)
                    .foregroundStyle(PlaceDetailVisualSystem.Colors.tertiary)
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var actionButton: some View {
        if let actionTitle, let action {
            Button(action: action) {
                Text(actionTitle)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .padding(.horizontal, PlaceDetailVisualSystem.Metrics.sectionActionHorizontalPadding)
                    .frame(minHeight: PlaceDetailVisualSystem.Metrics.sectionActionHeight)
                    .background(
                        Capsule()
                            .fill(Color.accentColor.opacity(actionBackgroundOpacity))
                            .overlay(
                                Capsule()
                                    .stroke(Color.accentColor.opacity(actionBorderOpacity), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(actionAccessibilityLabel ?? actionTitle)
        }
    }

    private var accessibilityLabel: String {
        guard let count else {
            return title
        }

        return "\(title), \(count)"
    }

    private var actionBackgroundOpacity: Double {
        colorScheme == .dark ? 0.24 : 0.10
    }

    private var actionBorderOpacity: Double {
        colorScheme == .dark ? 0.38 : 0
    }
}

struct PlaceDetailCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(PlaceDetailVisualSystem.Metrics.cardPadding)
            .background(
                RoundedRectangle(
                    cornerRadius: PlaceDetailVisualSystem.Metrics.cardCornerRadius,
                    style: .continuous
                )
                .fill(PlaceDetailVisualSystem.Colors.cardFill)
                .overlay {
                    RoundedRectangle(
                        cornerRadius: PlaceDetailVisualSystem.Metrics.cardCornerRadius,
                        style: .continuous
                    )
                    .stroke(PlaceDetailVisualSystem.Colors.cardStroke, lineWidth: 1)
                }
            )
    }
}

struct PlaceDetailEmptyStateCard: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        PlaceDetailCard {
            VStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(PlaceDetailVisualSystem.Colors.secondary)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color(uiColor: .tertiarySystemFill))
                    )

                VStack(spacing: 4) {
                    Text(title)
                        .font(PlaceDetailVisualSystem.Typography.cardTitle)
                        .foregroundStyle(PlaceDetailVisualSystem.Colors.primary)

                    Text(message)
                        .font(PlaceDetailVisualSystem.Typography.body)
                        .foregroundStyle(PlaceDetailVisualSystem.Colors.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct PlaceDetailReviewCard<LeadingVisual: View, Content: View>: View {
    let rating: Double
    var showsChevron = false
    private let onEdit: (() -> Void)?
    private let leadingVisual: LeadingVisual
    private let content: Content

    init(
        rating: Double,
        showsChevron: Bool = false,
        onEdit: (() -> Void)? = nil,
        @ViewBuilder leadingVisual: () -> LeadingVisual,
        @ViewBuilder content: () -> Content
    ) {
        self.rating = rating
        self.showsChevron = showsChevron
        self.onEdit = onEdit
        self.leadingVisual = leadingVisual()
        self.content = content()
    }

    var body: some View {
        PlaceDetailCard {
            HStack(alignment: .top, spacing: PlaceDetailVisualSystem.Metrics.columnSpacing) {
                leadingVisual
                    .frame(
                        width: PlaceDetailVisualSystem.Metrics.leadingVisualSize,
                        height: PlaceDetailVisualSystem.Metrics.leadingVisualSize
                    )

                VStack(alignment: .leading, spacing: PlaceDetailVisualSystem.Metrics.contentSpacing) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ReviewEditButton(action: onEdit) {
                    HStack(alignment: .top, spacing: PlaceDetailVisualSystem.Metrics.ratingAccessorySpacing) {
                        RatingBadgeView(rating: rating)

                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(PlaceDetailVisualSystem.Colors.tertiary)
                            .frame(width: PlaceDetailVisualSystem.Metrics.chevronWidth)
                            .frame(maxHeight: .infinity, alignment: .center)
                            .opacity(showsChevron ? 1 : 0)
                            .accessibilityHidden(!showsChevron)
                    }
                    .frame(
                        minWidth: PlaceDetailVisualSystem.Metrics.trailingAccessoryMinWidth,
                        maxHeight: .infinity,
                        alignment: .trailing
                    )
                }
            }
        }
    }
}

extension Date {
    var placeDetailTimestampText: String {
        L10n.relativeTime(self)
    }
}
