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
                LoadingStateView(title: L10n.loadingFriends)
            } else if viewModel.isPrivate {
                FriendListPrivacyStateView()
            } else if let errorMessage = viewModel.errorMessage, viewModel.friends.isEmpty {
                ErrorStateView(message: errorMessage) {
                    Task { await viewModel.load() }
                }
            } else if viewModel.friends.isEmpty {
                EmptyStateView(
                    title: L10n.noFriendsToShow,
                    message: L10n.valueDoesNotHaveVisibleFriendsYet(String(describing: user.displayName)),
                    systemImage: "person.2.slash"
                )
            } else {
                friendsList
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(L10n.friends)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: refreshCenter.globalRevision) {
            await viewModel.load()
        }
    }

    private var friendsList: some View {
        List {
            if let errorMessage = viewModel.errorMessage {
                InlineErrorBanner(title: L10n.couldnTRefreshFriends, message: errorMessage) {
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
        .trustMapReadableContent(maxWidth: 840)
        .refreshable {
            await viewModel.load()
        }
    }
}

struct FriendListPrivacyStateView: View {
    var body: some View {
        EmptyStateView(
            title: L10n.friendListPrivate,
            message: L10n.thisUserKeepsTheirFriendListPrivate,
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

                        Text(L10n.friendsSinceValue(String(describing: item.friendsSinceUtc.formatted(date: .abbreviated, time: .omitted))))
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
                Button(L10n.add, action: onAdd)
                    .buttonStyle(.borderedProminent)
            }
        case .friends:
            statusText(L10n.friends)
        case .outgoingRequest:
            statusText(L10n.pending)
        case .incomingRequest:
            statusText(L10n.incoming)
        case .self:
            statusText(L10n.you)
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
