import SwiftUI

struct NotificationRowView: View {
    let notification: TrustMapNotification

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AvatarView(
                name: notification.actor.displayName,
                avatarURL: notification.actor.avatarURL,
                size: 42,
                allowsFullscreen: false
            )
            .allowsHitTesting(false)

            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))

                Image(systemName: notification.systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 30, height: 30)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(notification.title)
                    .font(.subheadline.weight(notification.isUnread ? .semibold : .regular))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if !notification.subtitle.isEmpty {
                    Text(notification.subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Text(timestampText)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if notification.isUnread {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 8, height: 8)
                    .padding(.top, 7)
                    .accessibilityLabel("Unread")
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var timestampText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: notification.createdAtUtc, relativeTo: Date())
    }
}

#Preview {
    NotificationRowView(
        notification: TrustMapNotification(
            id: UUID(),
            type: .placeReviewAdded,
            createdAtUtc: Date().addingTimeInterval(-300),
            readAtUtc: nil,
            actor: UserSummary(
                id: UUID(),
                handle: "hubert#1234",
                displayName: "Hubert",
                avatarURLString: nil
            ),
            placeId: UUID(),
            placeName: "Caffe Aurora",
            placeReviewId: UUID(),
            dishReviewId: nil,
            dishName: nil,
            friendRequestId: nil,
            friendRequestStatus: nil,
            rating: 5
        )
    )
    .padding()
}
