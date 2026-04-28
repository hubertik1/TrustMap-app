import SwiftUI

struct ContributorSummaryRow: View {
    let contributors: [UserSummary]
    let totalContributorCount: Int
    let currentUserID: UUID?
    var avatarSize: CGFloat = 28
    var textFont: Font = .subheadline.weight(.medium)
    var textColor: Color = .secondary
    var avatarBorderColor = Color(uiColor: .systemBackground)

    var body: some View {
        if !contributors.isEmpty, let summaryText {
            HStack(spacing: 10) {
                ContributorAvatarStack(
                    contributors: contributors,
                    avatarSize: avatarSize,
                    borderColor: avatarBorderColor
                )

                Text(summaryText)
                    .font(textFont)
                    .foregroundStyle(textColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, minHeight: avatarSize + 2, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityText ?? summaryText)
        }
    }

    private var totalCount: Int {
        max(totalContributorCount, contributors.count)
    }

    private var summaryText: String? {
        guard let firstContributor = contributors.first else {
            return nil
        }

        let identity = contributorIdentity(for: firstContributor)
        guard totalCount > 1 else {
            return identity.isCurrentUser ? "Reviewed by you" : "Reviewed by \(identity.name)"
        }

        if identity.isFallback {
            return "\(totalCount) people reviewed"
        }

        let leadingName = identity.isCurrentUser ? "You" : identity.name
        return "\(leadingName) + \(totalCount - 1) reviewed"
    }

    private var accessibilityText: String? {
        guard let firstContributor = contributors.first else {
            return nil
        }

        let identity = contributorIdentity(for: firstContributor)
        guard totalCount > 1 else {
            return identity.isCurrentUser ? "Reviewed by you" : "Reviewed by \(identity.name)"
        }

        if identity.isFallback {
            return "\(totalCount) people reviewed"
        }

        let leadingName = identity.isCurrentUser ? "You" : identity.name
        let others = totalCount - 1
        return "\(leadingName) and \(others) \(others == 1 ? "other" : "others") reviewed"
    }

    private func contributorIdentity(for contributor: UserSummary) -> (name: String, isCurrentUser: Bool, isFallback: Bool) {
        if contributor.id == currentUserID {
            return ("you", true, false)
        }

        if let displayName = contributor.contributorDisplayName {
            return (displayName, false, false)
        }

        return ("Someone", false, true)
    }
}

private struct ContributorAvatarStack: View {
    let contributors: [UserSummary]
    let avatarSize: CGFloat
    let borderColor: Color

    private let overlap: CGFloat = 9

    private var visibleContributors: [UserSummary] {
        Array(contributors.prefix(3))
    }

    private var stackWidth: CGFloat {
        guard !visibleContributors.isEmpty else {
            return 0
        }

        return avatarSize + CGFloat(visibleContributors.count - 1) * (avatarSize - overlap)
    }

    var body: some View {
        HStack(spacing: -overlap) {
            ForEach(Array(visibleContributors.enumerated()), id: \.element.id) { index, contributor in
                AvatarView(
                    name: contributor.contributorDisplayName ?? "Someone",
                    avatarURL: contributor.avatarURL,
                    size: avatarSize,
                    allowsFullscreen: false
                )
                .overlay {
                    Circle()
                        .stroke(borderColor, lineWidth: 2)
                }
                .zIndex(Double(visibleContributors.count - index))
                .accessibilityHidden(true)
            }
        }
        .frame(width: stackWidth, height: avatarSize, alignment: .leading)
    }
}

extension UserSummary {
    var contributorDisplayName: String? {
        let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedDisplayName.isEmpty {
            return trimmedDisplayName
        }

        let trimmedHandleBase = handleComponents.base.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedHandleBase.isEmpty {
            return trimmedHandleBase
        }

        let trimmedHandle = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedHandle.isEmpty {
            return trimmedHandle
        }

        return nil
    }
}
