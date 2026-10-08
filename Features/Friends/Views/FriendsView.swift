import SwiftUI

struct FriendsView: View {
    @ObservedObject private var container: AppContainer
    @ObservedObject private var refreshCenter: AppRefreshCenter
    @StateObject private var viewModel: FriendsViewModel
    @State private var selectedFriendProfile: FriendProfileRoute?
    @State private var requestPendingCancellationID: UUID?
    @State private var friendPendingRemovalID: UUID?
    @FocusState private var isSearchFieldFocused: Bool

    init(container: AppContainer) {
        self.container = container
        self.refreshCenter = container.refreshCenter
        _viewModel = StateObject(
            wrappedValue: FriendsViewModel(
                refreshCenter: container.refreshCenter,
                userRepository: container.userRepository,
                friendRepository: container.friendRepository
            )
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField

            Group {
                if viewModel.isLoading && !viewModel.hasLoadedRelationships {
                    LoadingStateView(title: L10n.loadingFriends)
                } else if let errorMessage = viewModel.errorMessage, !viewModel.hasLoadedRelationships {
                    ErrorStateView(message: errorMessage) {
                        Task { await viewModel.load() }
                    }
                } else {
                    friendsList
                }
            }
        }
        .trustMapReadableContent(maxWidth: 840)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(L10n.friends)
        .onChange(of: viewModel.searchText) { _, _ in
            viewModel.handleSearchTextChange()
        }
        .task(id: refreshCenter.globalRevision) {
            await viewModel.load()
        }
        .navigationDestination(item: $selectedFriendProfile) { route in
            FriendProfileView(
                container: container,
                userID: route.id,
                initialUser: route.initialUser
            )
        }
    }

    private var normalizedSearchQuery: String {
        viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(L10n.searchNamesOrUsernames, text: $viewModel.searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($isSearchFieldFocused)

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                    isSearchFieldFocused = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.clearSearch)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(uiColor: .separator).opacity(0.12), lineWidth: 1)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    private var friendsList: some View {
        List {
            if let errorMessage = viewModel.errorMessage {
                InlineErrorBanner(title: L10n.couldnTRefreshFriends, message: errorMessage) {
                    Task { await viewModel.load() }
                }
            }

            if !normalizedSearchQuery.isEmpty {
                if viewModel.isSearching && viewModel.searchResults.isEmpty {
                    HStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.small)
                        Text(L10n.searchingUsers)
                            .foregroundStyle(.secondary)
                    }
                } else if viewModel.searchResults.isEmpty {
                    Text(L10n.noUsers)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.searchResults) { result in
                        SearchResultRow(
                            result: result,
                            isBusy: viewModel.activeUserID == result.userID,
                            onOpenProfile: {
                                selectedFriendProfile = FriendProfileRoute(initialUser: result.user)
                            },
                            action: {
                                Task { await viewModel.sendRequest(to: result) }
                            }
                        )
                    }
                }
            }

            Section(L10n.incomingRequests) {
                if viewModel.incomingRequests.isEmpty {
                    Text(L10n.youDonTHaveAnyIncomingRequestsRightNow)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.incomingRequests) { request in
                        RequestRow(
                            avatarURL: request.avatarURL,
                            title: request.displayName,
                            subtitle: "@\(request.handle)",
                            createdAt: request.createdAt,
                            primaryActionTitle: L10n.accept,
                            secondaryActionTitle: L10n.reject,
                            isBusy: viewModel.activeUserID == request.userID,
                            onOpenProfile: {
                                selectedFriendProfile = FriendProfileRoute(initialUser: request.user)
                            },
                            primaryAction: {
                                Task { await viewModel.accept(request) }
                            },
                            secondaryAction: {
                                Task { await viewModel.reject(request) }
                            }
                        )
                    }
                }
            }

            Section(L10n.outgoingRequests) {
                if viewModel.outgoingRequests.isEmpty {
                    Text(L10n.youHavenTSentAnyPendingRequests)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.outgoingRequests) { request in
                        outgoingRequestRow(request)
                    }
                }
            }

            if viewModel.friends.isEmpty {
                Section(L10n.friends) {
                    Text(L10n.youDonTHaveAnyAcceptedFriendsYet)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section(L10n.friends) {
                    ForEach(viewModel.friends) { friend in
                        friendRow(friend)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .contentMargins(.top, 8, for: .scrollContent)
        .scrollDismissesKeyboard(.interactively)
        .simultaneousGesture(
            TapGesture().onEnded {
                isSearchFieldFocused = false
            }
        )
        .refreshable {
            await viewModel.load()
        }
    }

    private func outgoingRequestRow(_ request: FriendsViewModel.RequestListItem) -> some View {
        RequestRow(
            avatarURL: request.avatarURL,
            title: request.displayName,
            subtitle: "@\(request.handle)",
            createdAt: request.createdAt,
            primaryActionTitle: L10n.cancel,
            secondaryActionTitle: nil,
            isBusy: viewModel.activeUserID == request.userID,
            onOpenProfile: {
                selectedFriendProfile = FriendProfileRoute(initialUser: request.user)
            },
            primaryAction: {
                requestPendingCancellationID = request.id
                friendPendingRemovalID = nil
            },
            secondaryAction: {},
            showsPrimaryConfirmation: requestPendingCancellationID == request.id,
            primaryConfirmationActionTitle: L10n.cancelRequest,
            primaryConfirmationCancelTitle: L10n.keep,
            confirmPrimaryAction: {
                requestPendingCancellationID = nil
                Task { await viewModel.cancel(request) }
            },
            cancelPrimaryConfirmation: {
                requestPendingCancellationID = nil
            }
        )
    }

    private func friendRow(_ friend: FriendsViewModel.FriendListItem) -> some View {
        HStack(spacing: 12) {
            Button {
                selectedFriendProfile = FriendProfileRoute(initialUser: friend.user)
            } label: {
                HStack(spacing: 12) {
                    AvatarView(name: friend.displayName, avatarURL: friend.avatarURL)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(friend.displayName)
                        Text("@\(friend.handle)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if let bio = friend.bio, !bio.isEmpty {
                            Text(bio)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Text(L10n.addedValue(String(describing: friend.addedAt.formatted(date: .abbreviated, time: .omitted))))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .layoutPriority(1)

                    Spacer(minLength: 10)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if viewModel.activeUserID == friend.userID {
                ProgressView()
            } else {
                Button(L10n.remove, role: .destructive) {
                    friendPendingRemovalID = friend.id
                    requestPendingCancellationID = nil
                }
                .font(.caption.weight(.semibold))
                .controlSize(.small)
                .buttonStyle(.bordered)
                .popover(
                    isPresented: Binding(
                        get: { friendPendingRemovalID == friend.id },
                        set: { if !$0 { friendPendingRemovalID = nil } }
                    ),
                    attachmentAnchor: .rect(.bounds),
                    arrowEdge: .trailing
                ) {
                    DestructiveConfirmationPopover(
                        title: L10n.removeFriend,
                        message: L10n.areYouSureYouWantToRemoveValue(String(describing: friend.displayName)),
                        destructiveTitle: L10n.remove,
                        cancelTitle: L10n.keep,
                        destructiveAction: {
                            friendPendingRemovalID = nil
                            Task { await viewModel.remove(friend: friend) }
                        },
                        cancelAction: {
                            friendPendingRemovalID = nil
                        }
                    )
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct FriendProfileRoute: Identifiable, Hashable {
    let initialUser: UserSummary

    var id: UUID {
        initialUser.id
    }
}

private struct SearchResultRow: View {
    let result: FriendsViewModel.SearchResultItem
    let isBusy: Bool
    let onOpenProfile: () -> Void
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onOpenProfile) {
                HStack(spacing: 12) {
                    AvatarView(name: avatarName, avatarURL: result.avatarURL)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(primaryText)
                            .font(.body.weight(.semibold))
                            .lineLimit(1)
                        if shouldShowHandleSubtitle {
                            Text("@\(result.handle)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .layoutPriority(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .layoutPriority(1)

            Spacer(minLength: 10)

            relationshipControl
        }
        .frame(height: 56, alignment: .center)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var relationshipControl: some View {
        switch result.relationshipStatus {
        case .friends:
            statusText(L10n.friends)
        case .incomingRequest:
            statusText(L10n.incoming)
        case .outgoingRequest:
            statusText(L10n.pending)
        case .self:
            statusText(L10n.you)
        case .none:
            if isBusy {
                ProgressView()
            } else {
                Button(L10n.add, action: action)
                    .font(.caption.weight(.semibold))
                    .controlSize(.small)
                    .buttonStyle(.borderedProminent)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    private func statusText(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    private var primaryText: String {
        trimmedDisplayName.isEmpty ? "@\(result.handle)" : trimmedDisplayName
    }

    private var avatarName: String {
        trimmedDisplayName.isEmpty ? result.handle : trimmedDisplayName
    }

    private var shouldShowHandleSubtitle: Bool {
        !result.handle.isEmpty && !trimmedDisplayName.isEmpty
    }

    private var trimmedDisplayName: String {
        let displayName = result.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return displayName
    }
}

private struct RequestRow: View {
    let avatarURL: URL?
    let title: String
    let subtitle: String
    let createdAt: Date
    let primaryActionTitle: String
    let secondaryActionTitle: String?
    let isBusy: Bool
    let onOpenProfile: () -> Void
    let primaryAction: () -> Void
    let secondaryAction: () -> Void
    let showsPrimaryConfirmation: Bool
    let primaryConfirmationActionTitle: String
    let primaryConfirmationCancelTitle: String
    let confirmPrimaryAction: (() -> Void)?
    let cancelPrimaryConfirmation: (() -> Void)?

    init(
        avatarURL: URL?,
        title: String,
        subtitle: String,
        createdAt: Date,
        primaryActionTitle: String,
        secondaryActionTitle: String?,
        isBusy: Bool,
        onOpenProfile: @escaping () -> Void,
        primaryAction: @escaping () -> Void,
        secondaryAction: @escaping () -> Void,
        showsPrimaryConfirmation: Bool = false,
        primaryConfirmationActionTitle: String = L10n.confirm,
        primaryConfirmationCancelTitle: String = L10n.keep,
        confirmPrimaryAction: (() -> Void)? = nil,
        cancelPrimaryConfirmation: (() -> Void)? = nil
    ) {
        self.avatarURL = avatarURL
        self.title = title
        self.subtitle = subtitle
        self.createdAt = createdAt
        self.primaryActionTitle = primaryActionTitle
        self.secondaryActionTitle = secondaryActionTitle
        self.isBusy = isBusy
        self.onOpenProfile = onOpenProfile
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
        self.showsPrimaryConfirmation = showsPrimaryConfirmation
        self.primaryConfirmationActionTitle = primaryConfirmationActionTitle
        self.primaryConfirmationCancelTitle = primaryConfirmationCancelTitle
        self.confirmPrimaryAction = confirmPrimaryAction
        self.cancelPrimaryConfirmation = cancelPrimaryConfirmation
    }

    var body: some View {
        if secondaryActionTitle == nil {
            outgoingStyleRow
        } else {
            incomingStyleRow
        }
    }

    private var outgoingStyleRow: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: onOpenProfile) {
                personInfo
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .layoutPriority(1)

            Spacer(minLength: 10)

            requestActions
        }
        .padding(.vertical, 4)
    }

    private var incomingStyleRow: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onOpenProfile) {
                AvatarView(name: title, avatarURL: avatarURL)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 12) {
                Button(action: onOpenProfile) {
                    requestText
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                requestActions
            }
            .layoutPriority(1)
        }
        .padding(.vertical, 4)
    }

    private var personInfo: some View {
        HStack(spacing: 12) {
            AvatarView(name: title, avatarURL: avatarURL)
            requestText
                .layoutPriority(1)
        }
    }

    private var requestText: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(createdAt, style: .date)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var requestActions: some View {
        if isBusy {
            ProgressView()
        } else if let secondaryActionTitle {
            HStack(spacing: 8) {
                Button(primaryActionTitle, action: primaryAction)
                    .font(.caption.weight(.semibold))
                    .controlSize(.small)
                    .buttonStyle(.borderedProminent)
                    .fixedSize(horizontal: true, vertical: false)

                Button(secondaryActionTitle, role: .destructive, action: secondaryAction)
                    .font(.caption.weight(.semibold))
                    .controlSize(.small)
                    .buttonStyle(.bordered)
                    .fixedSize(horizontal: true, vertical: false)
            }
        } else {
            Button(role: .destructive, action: primaryAction) {
                Text(primaryActionTitle)
            }
            .font(.caption.weight(.semibold))
            .controlSize(.small)
            .buttonStyle(.bordered)
            .fixedSize(horizontal: true, vertical: false)
            .popover(
                isPresented: primaryConfirmationBinding,
                attachmentAnchor: .rect(.bounds),
                arrowEdge: .trailing
            ) {
                if let confirmPrimaryAction, let cancelPrimaryConfirmation {
                    DestructiveConfirmationPopover(
                        title: L10n.confirmCancelRequest,
                        message: L10n.areYouSureYouWantToCancelThisFriendRequest,
                        destructiveTitle: primaryConfirmationActionTitle,
                        cancelTitle: primaryConfirmationCancelTitle,
                        destructiveAction: confirmPrimaryAction,
                        cancelAction: cancelPrimaryConfirmation
                    )
                }
            }
        }
    }

    private var primaryConfirmationBinding: Binding<Bool> {
        Binding(
            get: { showsPrimaryConfirmation },
            set: { isPresented in
                if !isPresented {
                    cancelPrimaryConfirmation?()
                }
            }
        )
    }
}

private struct DestructiveConfirmationPopover: View {
    let title: String
    let message: String
    let destructiveTitle: String
    let cancelTitle: String
    let destructiveAction: () -> Void
    let cancelAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Button(action: cancelAction) {
                    PopoverActionButtonLabel(title: cancelTitle, foregroundStyle: .primary)
                }
                .buttonStyle(.plain)

                Button(role: .destructive, action: destructiveAction) {
                    PopoverActionButtonLabel(title: destructiveTitle, foregroundStyle: .red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(width: 270, alignment: .leading)
        .presentationCompactAdaptation(.popover)
    }
}

private struct PopoverActionButtonLabel: View {
    let title: String
    let foregroundStyle: Color

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(foregroundStyle)
            .padding(.horizontal, 14)
            .frame(minHeight: 36)
            .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
            .fixedSize(horizontal: true, vertical: false)
    }
}

#Preview {
    NavigationStack {
        FriendsView(container: PreviewAppFactory.makeContainer())
    }
}
