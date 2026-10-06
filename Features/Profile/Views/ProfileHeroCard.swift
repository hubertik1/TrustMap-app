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
                friendsStat: .friends(count: friendCount, canViewFriends: user.canViewFriends),
                pendingRequestCount: pendingRequestCount,
                placesStat: .places(count: ratedPlacesCount, canViewReviews: user.canViewReviews),
                dishesStat: .dishes(count: reviewedDishesCount, canViewReviews: user.canViewReviews),
                canNavigateToFriends: canNavigateToFriends && user.canViewFriends
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
    let friendsStat: ProfileStatDisplay
    let pendingRequestCount: Int
    let placesStat: ProfileStatDisplay
    let dishesStat: ProfileStatDisplay
    let canNavigateToFriends: Bool
    @ViewBuilder let friendsDestination: () -> FriendsDestination
    @ViewBuilder let placesDestination: () -> PlacesDestination
    @ViewBuilder let dishesDestination: () -> DishesDestination

    var body: some View {
        HStack(spacing: 0) {
            stat(canNavigate: canNavigateToFriends, value: friendsStat.value, title: friendsStat.title,
                 pendingRequests: pendingRequestCount, label: friendsAccessibilityLabel,
                 hint: "Opens friends", destination: friendsDestination)
            ProfileStatDivider()
            stat(canNavigate: !placesStat.isPrivate, value: placesStat.value, title: placesStat.title,
                 label: "\(placesStat.value) rated places", hint: "Opens places", destination: placesDestination)
            ProfileStatDivider()
            stat(canNavigate: !dishesStat.isPrivate, value: dishesStat.value, title: dishesStat.title,
                 label: "\(dishesStat.value) reviewed dishes", hint: "Opens dishes", destination: dishesDestination)
        }
    }

    @ViewBuilder
    private func stat<Destination: View>(canNavigate: Bool, value: String, title: String,
                                         pendingRequests: Int = 0, label: String, hint: String,
                                         @ViewBuilder destination: () -> Destination) -> some View {
        if canNavigate {
            NavigationLink {
                destination()
            } label: {
                ProfileStatColumn(valueText: value, label: title, pendingRequestCount: pendingRequests,
                                  accessibilityLabel: label, accessibilityHint: hint)
            }
            .buttonStyle(ProfileStatNavigationButtonStyle())
        } else {
            ProfileStatColumn(valueText: value, label: title, pendingRequestCount: pendingRequests,
                              accessibilityLabel: label, accessibilityHint: "")
        }
    }

    private var friendsAccessibilityLabel: String {
        if pendingRequestCount == 1 {
            return "\(friendsStat.value) friends, 1 pending request"
        }

        if pendingRequestCount > 1 {
            return "\(friendsStat.value) friends, \(pendingRequestCount) pending requests"
        }

        return "\(friendsStat.value) friends"
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
    let valueText: String
    let label: String
    var pendingRequestCount = 0
    let accessibilityLabel: String
    let accessibilityHint: String

    private var pendingRequestBadgeText: String {
        pendingRequestCount > 9 ? "9+" : pendingRequestCount.formatted()
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(valueText)
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
