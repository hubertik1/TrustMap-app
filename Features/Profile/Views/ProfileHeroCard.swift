import SwiftUI

struct ProfileHeroCard<FriendsDestination: View, PlacesDestination: View, DishesDestination: View>: View {
    let user: User
    let friendCount: Int
    let pendingRequestCount: Int
    let ratedPlacesCount: Int
    let reviewedDishesCount: Int
    let onEditProfile: (() -> Void)?
    var canNavigateToFriends = true
    @ViewBuilder let friendsDestination: () -> FriendsDestination
    @ViewBuilder let placesDestination: () -> PlacesDestination
    @ViewBuilder let dishesDestination: () -> DishesDestination

    private var bioText: String? {
        let trimmedBio = user.bio?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedBio.isEmpty ? nil : trimmedBio
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 15) {
                AvatarView(name: user.displayName, avatarURL: user.avatarURL, size: 86)
                    .overlay {
                        Circle()
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Profile photo")

                VStack(alignment: .leading, spacing: 5) {
                    Text(user.displayName)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)

                    Text("@\(user.handle)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    if let onEditProfile {
                        Button(action: onEditProfile) {
                            Text("Edit Profile")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 6)
                                .background(Color.accentColor.opacity(0.07), in: Capsule())
                                .overlay {
                                    Capsule()
                                        .stroke(Color.accentColor.opacity(0.18), lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 3)
                        .accessibilityLabel("Edit Profile")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let bioText {
                Text(bioText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(onEditProfile == nil ? "No bio yet." : "Add a short bio to help friends recognize you.")
                    .font(.subheadline)
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            ProfileStatsRow(
                friendCount: friendCount,
                pendingRequestCount: pendingRequestCount,
                ratedPlacesCount: ratedPlacesCount,
                reviewedDishesCount: reviewedDishesCount,
                canNavigateToFriends: canNavigateToFriends
            ) {
                friendsDestination()
            } placesDestination: {
                placesDestination()
            } dishesDestination: {
                dishesDestination()
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.035), radius: 10, x: 0, y: 4)
    }
}

private struct ProfileStatsRow<FriendsDestination: View, PlacesDestination: View, DishesDestination: View>: View {
    let friendCount: Int
    let pendingRequestCount: Int
    let ratedPlacesCount: Int
    let reviewedDishesCount: Int
    let canNavigateToFriends: Bool
    @ViewBuilder let friendsDestination: () -> FriendsDestination
    @ViewBuilder let placesDestination: () -> PlacesDestination
    @ViewBuilder let dishesDestination: () -> DishesDestination

    var body: some View {
        HStack(spacing: 0) {
            NavigationLink {
                friendsDestination()
            } label: {
                ProfileStatColumn(
                    count: friendCount,
                    label: "Friends",
                    pendingRequestCount: pendingRequestCount,
                    accessibilityLabel: friendsAccessibilityLabel,
                    accessibilityHint: canNavigateToFriends ? "Opens friends" : "Opens friend list privacy status"
                )
            }
            .buttonStyle(ProfileStatNavigationButtonStyle())

            ProfileStatDivider()

            NavigationLink {
                placesDestination()
            } label: {
                ProfileStatColumn(
                    count: ratedPlacesCount,
                    label: "Places",
                    accessibilityLabel: "\(ratedPlacesCount) rated places",
                    accessibilityHint: "Opens places"
                )
            }
            .buttonStyle(ProfileStatNavigationButtonStyle())

            ProfileStatDivider()

            NavigationLink {
                dishesDestination()
            } label: {
                ProfileStatColumn(
                    count: reviewedDishesCount,
                    label: "Dishes",
                    accessibilityLabel: "\(reviewedDishesCount) reviewed dishes",
                    accessibilityHint: "Opens dishes"
                )
            }
            .buttonStyle(ProfileStatNavigationButtonStyle())
        }
    }

    private var friendsAccessibilityLabel: String {
        if pendingRequestCount == 1 {
            return "\(friendCount) friends, 1 pending request"
        }

        if pendingRequestCount > 1 {
            return "\(friendCount) friends, \(pendingRequestCount) pending requests"
        }

        return "\(friendCount) friends"
    }
}

private struct ProfileStatNavigationButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.045 : 0))
            }
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct ProfileStatColumn: View {
    let count: Int
    let label: String
    var pendingRequestCount = 0
    let accessibilityLabel: String
    let accessibilityHint: String

    private var pendingRequestBadgeText: String {
        pendingRequestCount > 9 ? "9+" : pendingRequestCount.formatted()
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(count.formatted())
                .font(.headline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            HStack(spacing: 5) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                if pendingRequestCount > 0 {
                    Text(pendingRequestBadgeText)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, 5)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(.red, in: Capsule())
                        .fixedSize(horizontal: true, vertical: false)
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 52)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(.isButton)
    }
}

private struct ProfileStatDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.06))
            .frame(width: 1, height: 36)
            .accessibilityHidden(true)
    }
}
