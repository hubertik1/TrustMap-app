import SwiftUI

/// A fictional place and two fictional friends, not app-wide social proof.
struct WelcomeDemoPlaceCard: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(verbatim: "Sunday Table")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
                VStack(spacing: 4) {
                    RatingBadgeView(rating: 4.5)
                    Text(L10n.welcomeAverageRating)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                Image("WelcomeDemoFood")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.restaurants)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(L10n.welcomeExampleReview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider()

            HStack(spacing: 8) {
                Text(L10n.trustedByFriends(2))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                HStack(spacing: -8) {
                    avatar("WelcomeDemoMia")
                    avatar("WelcomeDemoEli")
                }
            }
        }
        .padding(13)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(
                    colors: colorScheme == .dark
                        ? [Color(red: 0.08, green: 0.10, blue: 0.19), Color(red: 0.12, green: 0.15, blue: 0.27)]
                        : [.white, Color(red: 0.94, green: 0.97, blue: 1.0)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    Color.gray.opacity(colorScheme == .dark ? 0.28 : 0.18),
                    lineWidth: 0.75
                )
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.16), radius: 12, y: 5)
    }

    private func avatar(_ asset: String) -> some View {
        Image(asset)
            .resizable()
            .scaledToFill()
            .frame(width: 32, height: 32)
            .clipShape(Circle())
            .overlay {
                Circle().strokeBorder(.background, lineWidth: 2)
            }
    }
}
