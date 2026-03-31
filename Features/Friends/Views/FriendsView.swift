import SwiftUI
import UIKit

struct FriendsView: View {
    @StateObject private var viewModel: FriendsViewModel

    init(container: AppContainer) {
        _viewModel = StateObject(
            wrappedValue: FriendsViewModel(
                sessionStore: container.sessionStore,
                cloudKitSyncService: container.cloudKitSyncService,
                userRepository: container.userRepository,
                friendRepository: container.friendRepository,
                inviteLinkBuilder: container.inviteLinkBuilder
            )
        )
    }

    var body: some View {
        Group {
            if viewModel.isLoading && !viewModel.hasAnyEntries {
                LoadingStateView(title: "Loading friends")
            } else if let errorMessage = viewModel.errorMessage, !viewModel.hasAnyEntries {
                ErrorStateView(message: errorMessage) {
                    Task { await viewModel.load() }
                }
            } else {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            Button {
                                Task { await viewModel.addFriend() }
                            } label: {
                                Text(viewModel.isPreparingInvite ? "Preparing Invite…" : "Add Friend")
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        Capsule()
                                            .fill(
                                                viewModel.isMutating
                                                    ? Color.accentColor.opacity(0.6)
                                                    : Color.accentColor
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                            .disabled(viewModel.isMutating)

                            Text("TrustMap creates a unique invite link and opens the iOS share sheet right away.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }

                    if !viewModel.incomingInvites.isEmpty {
                        Section("Awaiting Your Response") {
                            ForEach(viewModel.incomingInvites) { invite in
                                IncomingInviteRow(
                                    invite: invite,
                                    isProcessing: viewModel.activeInviteID == invite.id
                                ) {
                                    Task { await viewModel.accept(invite) }
                                } onDecline: {
                                    Task { await viewModel.decline(invite) }
                                }
                            }
                        }
                    }

                    if viewModel.friends.isEmpty && !viewModel.hasAnyEntries {
                        Section {
                            EmptyFriendsState()
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                        }
                    } else if viewModel.friends.isEmpty {
                        Section("Friends") {
                            Text("You don’t have any accepted friends yet.")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Section("Friends") {
                            ForEach(viewModel.friends) { friend in
                                HStack(spacing: 12) {
                                    AvatarView(name: friend.displayName)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(friend.displayName)
                                        if let bio = friend.bio, !bio.isEmpty {
                                            Text(bio)
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                        Text("Added \(friend.addedAt.formatted(date: .abbreviated, time: .omitted))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable {
                    await viewModel.load()
                }
            }
        }
        .navigationTitle("Friends")
        .sheet(item: $viewModel.sharePayload) { payload in
            InviteShareSheet(activityItems: payload.activityItems)
        }
        .onAppear {
            Task { await viewModel.load() }
        }
    }
}

private struct IncomingInviteRow: View {
    let invite: FriendsViewModel.IncomingInviteListItem
    let isProcessing: Bool
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                AvatarView(name: invite.inviterName)
                VStack(alignment: .leading, spacing: 4) {
                    Text(invite.inviterName)
                        .font(.headline)
                    if let inviterBio = invite.inviterBio, !inviterBio.isEmpty {
                        Text(inviterBio)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text(invite.createdAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Button("Accept", action: onAccept)
                    .buttonStyle(.borderedProminent)
                Button("Decline", role: .destructive, action: onDecline)
                    .buttonStyle(.bordered)
            }
            .disabled(isProcessing)
        }
        .padding(.vertical, 4)
    }
}

private struct EmptyFriendsState: View {
    var body: some View {
        VStack(spacing: 16) {
            EmptyStateView(
                title: "No Friends Yet",
                message: "You don’t have any accepted friends yet.",
                systemImage: "person.2.slash"
            )
            .frame(maxHeight: 220)
        }
        .padding(.vertical, 12)
    }
}

private struct InviteShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        FriendsView(container: PreviewAppFactory.makeContainer())
    }
}
