import SwiftUI

struct AcceptInviteView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AcceptInviteViewModel

    init(container: AppContainer, token: String) {
        _viewModel = StateObject(
            wrappedValue: AcceptInviteViewModel(
                token: token,
                sessionStore: container.sessionStore,
                userRepository: container.userRepository,
                friendRepository: container.friendRepository
            )
        )
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                LoadingStateView(title: "Adding friend")

            case .valid(let context):
                InviteStateCard(
                    context: context,
                    title: "\(context.inviterName) wants to add you on TrustMap.",
                    message: "Accept to share friends-only places, reviews, dishes, photos, and feed updates with each other.",
                    systemImage: "person.2.fill",
                    tint: .accentColor
                ) {
                    HStack {
                        Button("Accept") {
                            Task { await viewModel.accept() }
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Decline", role: .destructive) {
                            Task { await viewModel.decline() }
                        }
                        .buttonStyle(.bordered)
                    }
                    .disabled(viewModel.isPerformingAction)
                }

            case .alreadyAccepted(let context):
                InviteStateCard(
                    context: context,
                    title: "Invite accepted",
                    message: "You are now connected as friends on TrustMap.",
                    systemImage: "checkmark.circle.fill",
                    tint: .green
                )

            case .alreadyFriends(let context):
                InviteStateCard(
                    context: context,
                    title: "You’re already friends",
                    message: "No new relationship was created because you’re already connected.",
                    systemImage: "person.2.circle.fill",
                    tint: .green
                )

            case .expired(let context):
                InviteStateCard(
                    context: context,
                    title: "Invite expired",
                    message: "This invite is no longer valid.",
                    systemImage: "clock.badge.xmark.fill",
                    tint: .orange
                )

            case .invalid:
                InviteMessageState(
                    title: "Invalid invite",
                    message: "This invite link is invalid or no longer available.",
                    systemImage: "exclamationmark.triangle.fill",
                    tint: .orange
                )

            case .ownInvite(let context):
                InviteStateCard(
                    context: context,
                    title: "This is your invite",
                    message: "You can’t accept your own friend invite.",
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    tint: .orange
                )

            case .declined(let context):
                InviteStateCard(
                    context: context,
                    title: "Invite declined",
                    message: "This invite has already been declined.",
                    systemImage: "xmark.circle.fill",
                    tint: .red
                )

            case .revoked(let context):
                InviteStateCard(
                    context: context,
                    title: "Invite canceled",
                    message: "The sender canceled this invite before it was accepted.",
                    systemImage: "minus.circle.fill",
                    tint: .secondary
                )

            case .genericError(let message):
                InviteMessageState(
                    title: "Couldn’t open invite",
                    message: message,
                    systemImage: "exclamationmark.triangle.fill",
                    tint: .red
                )
            }
        }
        .padding()
        .navigationTitle("Friend Invite")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
        .task {
            await viewModel.load()
        }
    }
}

private struct InviteStateCard<Actions: View>: View {
    let context: AcceptInviteViewModel.InviteContext
    let title: String
    let message: String
    let systemImage: String
    let tint: Color
    @ViewBuilder let actions: Actions

    init(
        context: AcceptInviteViewModel.InviteContext,
        title: String,
        message: String,
        systemImage: String,
        tint: Color,
        @ViewBuilder actions: () -> Actions = { EmptyView() }
    ) {
        self.context = context
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.tint = tint
        self.actions = actions()
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: systemImage)
                .font(.system(size: 42))
                .foregroundStyle(tint)

            AvatarView(name: context.inviterName, size: 72)

            VStack(spacing: 8) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if let inviterBio = context.inviterBio, !inviterBio.isEmpty {
                    Text(inviterBio)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Text("Sent \(context.createdAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            actions
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct InviteMessageState: View {
    let title: String
    let message: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 42))
                .foregroundStyle(tint)

            Text(title)
                .font(.title3.weight(.semibold))

            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    NavigationStack {
        AcceptInviteView(container: PreviewAppFactory.makeContainer(), token: "preview-token")
    }
}
