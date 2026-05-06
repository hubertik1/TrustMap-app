import SwiftUI

struct UserFriendsView: View {
    let user: User
    @ObservedObject private var container: AppContainer
    @ObservedObject private var refreshCenter: AppRefreshCenter
    @StateObject private var viewModel: UserFriendsViewModel

    init(container: AppContainer, user: User) {
        self.user = user
        self.container = container
        self.refreshCenter = container.refreshCenter
        _viewModel = StateObject(
            wrappedValue: UserFriendsViewModel(
                targetUserID: user.id,
                refreshCenter: container.refreshCenter,
                friendRepository: container.friendRepository
            )
        )
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.friends.isEmpty {
                LoadingStateView(title: "Loading friends")
            } else if viewModel.isPrivate {
                FriendListPrivacyStateView()
            } else if let errorMessage = viewModel.errorMessage, viewModel.friends.isEmpty {
                ErrorStateView(message: errorMessage) {
                    Task { await viewModel.load() }
                }
            } else if viewModel.friends.isEmpty {
                EmptyStateView(
                    title: "No friends to show",
                    message: "\(user.displayName) does not have visible friends yet.",
                    systemImage: "person.2.slash"
                )
            } else {
                friendsList
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Friends")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: refreshCenter.globalRevision) {
            await viewModel.load()
        }
    }

    private var friendsList: some View {
        List {
            if let errorMessage = viewModel.errorMessage {
                InlineErrorBanner(title: "Couldn't refresh friends", message: errorMessage) {
                    Task { await viewModel.load() }
                }
            }

            Section(user.displayName) {
                ForEach(viewModel.friends) { friend in
                    UserFriendRow(
                        container: container,
                        item: friend,
                        isBusy: viewModel.activeUserID == friend.id
                    ) {
                        Task { await viewModel.sendRequest(to: friend) }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .contentMargins(.top, 8, for: .scrollContent)
        .refreshable {
            await viewModel.load()
        }
    }
}

struct FriendListPrivacyStateView: View {
    var body: some View {
        EmptyStateView(
            title: "Friend list private",
            message: "This user keeps their friend list private.",
            systemImage: "lock.fill"
        )
    }
}

private struct UserFriendRow: View {
    @ObservedObject var container: AppContainer
    let item: UserFriendListItem
    let isBusy: Bool
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            NavigationLink {
                FriendProfileView(
                    container: container,
                    userID: item.user.id,
                    initialUser: item.user
                )
            } label: {
                HStack(spacing: 12) {
                    AvatarView(name: item.user.displayName, avatarURL: item.user.avatarURL)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(primaryText)
                            .font(.body.weight(.semibold))
                            .lineLimit(1)

                        if shouldShowHandleSubtitle {
                            Text("@\(item.user.handle)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Text("Friends since \(item.friendsSinceUtc.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .layoutPriority(1)
                }
            }
            .buttonStyle(.plain)
            .layoutPriority(1)

            Spacer(minLength: 10)

            relationshipControl
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var relationshipControl: some View {
        switch item.relationshipStatus {
        case .none:
            if isBusy {
                ProgressView()
            } else {
                Button("Add", action: onAdd)
                    .buttonStyle(.borderedProminent)
            }
        case .friends:
            statusText("Friends")
        case .outgoingRequest:
            statusText("Pending")
        case .incomingRequest:
            statusText("Incoming")
        case .self:
            statusText("You")
        }
    }

    private func statusText(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    private var primaryText: String {
        trimmedDisplayName.isEmpty ? "@\(item.user.handle)" : trimmedDisplayName
    }

    private var shouldShowHandleSubtitle: Bool {
        !item.user.handle.isEmpty && !trimmedDisplayName.isEmpty
    }

    private var trimmedDisplayName: String {
        item.user.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview {
    NavigationStack {
        UserFriendsView(container: PreviewAppFactory.makeContainer(), user: PreviewAppFactory.sampleUser)
    }
}
