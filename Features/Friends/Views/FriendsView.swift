import SwiftUI

struct FriendsView: View {
    @ObservedObject private var refreshCenter: AppRefreshCenter
    @StateObject private var viewModel: FriendsViewModel
    @FocusState private var isSearchFieldFocused: Bool

    init(container: AppContainer) {
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
                    LoadingStateView(title: "Loading friends")
                } else if let errorMessage = viewModel.errorMessage, !viewModel.hasLoadedRelationships {
                    ErrorStateView(message: errorMessage) {
                        Task { await viewModel.load() }
                    }
                } else {
                    friendsList
                }
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Friends")
        .onChange(of: viewModel.searchText) { _, _ in
            viewModel.handleSearchTextChange()
        }
        .task(id: refreshCenter.globalRevision) {
            await viewModel.load()
        }
    }

    private var normalizedSearchQuery: String {
        viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search usernames", text: $viewModel.searchText)
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
                .accessibilityLabel("Clear search")
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
                InlineErrorBanner(title: "Couldn't refresh friends", message: errorMessage) {
                    Task { await viewModel.load() }
                }
            }

            if normalizedSearchQuery.count < 2 {
                Text("Search by username to add friends.")
                    .foregroundStyle(.secondary)
            } else if viewModel.isSearching && viewModel.searchResults.isEmpty {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Searching users...")
                        .foregroundStyle(.secondary)
                }
            } else if viewModel.searchResults.isEmpty {
                Text("No matching users.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.searchResults) { result in
                    SearchResultRow(
                        result: result,
                        isBusy: viewModel.activeUserID == result.userID
                    ) {
                        Task { await viewModel.sendRequest(to: result) }
                    }
                }
            }

            Section("Incoming Requests") {
                if viewModel.incomingRequests.isEmpty {
                    Text("You don’t have any incoming requests right now.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.incomingRequests) { request in
                        RequestRow(
                            avatarURL: request.avatarURL,
                            title: request.displayName,
                            subtitle: "@\(request.handle)",
                            createdAt: request.createdAt,
                            primaryActionTitle: "Accept",
                            secondaryActionTitle: "Reject",
                            isBusy: viewModel.activeUserID == request.userID
                        ) {
                            Task { await viewModel.accept(request) }
                        } secondaryAction: {
                            Task { await viewModel.reject(request) }
                        }
                    }
                }
            }

            Section("Outgoing Requests") {
                if viewModel.outgoingRequests.isEmpty {
                    Text("You haven’t sent any pending requests.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.outgoingRequests) { request in
                        RequestRow(
                            avatarURL: request.avatarURL,
                            title: request.displayName,
                            subtitle: "@\(request.handle)",
                            createdAt: request.createdAt,
                            primaryActionTitle: "Cancel",
                            secondaryActionTitle: nil,
                            isBusy: viewModel.activeUserID == request.userID
                        ) {
                            Task { await viewModel.cancel(request) }
                        } secondaryAction: {}
                    }
                }
            }

            if viewModel.friends.isEmpty {
                Section("Friends") {
                    Text("You don’t have any accepted friends yet.")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section("Friends") {
                    ForEach(viewModel.friends) { friend in
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
                                Text("Added \(friend.addedAt.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if viewModel.activeUserID == friend.userID {
                                ProgressView()
                            } else {
                                Button("Remove", role: .destructive) {
                                    Task { await viewModel.remove(friend: friend) }
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, 4)
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
}

private struct SearchResultRow: View {
    let result: FriendsViewModel.SearchResultItem
    let isBusy: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(name: result.displayName, avatarURL: result.avatarURL)

            VStack(alignment: .leading, spacing: 4) {
                Text("@\(result.handle)")
                    .font(.headline.monospacedDigit())
                Text(result.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            switch result.relationshipStatus {
            case .friends:
                Text("Friends")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            case .incomingRequest:
                Text("Incoming")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            case .outgoingRequest:
                Text("Pending")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            case .self:
                Text("You")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            case .none:
                if isBusy {
                    ProgressView()
                } else {
                    Button("Add", action: action)
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(.vertical, 4)
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
    let primaryAction: () -> Void
    let secondaryAction: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AvatarView(name: title, avatarURL: avatarURL)

            VStack(alignment: .leading, spacing: 12) {
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

                HStack {
                    if isBusy {
                        ProgressView()
                    } else {
                        Button(primaryActionTitle, action: primaryAction)
                            .buttonStyle(.borderedProminent)

                        if let secondaryActionTitle {
                            Button(secondaryActionTitle, role: .destructive, action: secondaryAction)
                                .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        FriendsView(container: PreviewAppFactory.makeContainer())
    }
}
