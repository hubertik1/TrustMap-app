import SwiftUI

struct BlockedUsersView: View {
    @StateObject private var viewModel: BlockedUsersViewModel
    @State private var selectedUser: BlockedUser?

    init(repository: SafetyRepository) {
        _viewModel = StateObject(wrappedValue: BlockedUsersViewModel(repository: repository))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.users.isEmpty {
                LoadingStateView(title: L10n.loadingBlockedUsers)
            } else if let error = viewModel.errorMessage, viewModel.users.isEmpty {
                ErrorStateView(message: error) { Task { await viewModel.load() } }
            } else if viewModel.users.isEmpty {
                EmptyStateView(title: L10n.noBlockedUsers, message: L10n.peopleYouBlockWillAppearHere, systemImage: "person.crop.circle.badge.checkmark")
            } else {
                List(viewModel.users) { user in
                    HStack(spacing: 12) {
                        AvatarView(name: user.displayName, avatarURL: nil, size: 44)
                        VStack(alignment: .leading) {
                            Text(user.displayName).font(.headline)
                            Text("@\(user.handle)").font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(L10n.unblock) { selectedUser = user }
                            .disabled(viewModel.unblockingID != nil)
                            .accessibilityLabel(L10n.unblockValue(String(describing: user.displayName)))
                    }
                }
                .refreshable { await viewModel.load() }
            }
        }
        .navigationTitle(L10n.blockedUsers)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .confirmationDialog(L10n.confirmUnblockUser(String(describing: selectedUser?.displayName ?? L10n.trustmapUser)), isPresented: Binding(
            get: { selectedUser != nil }, set: { if !$0 { selectedUser = nil } }
        ), titleVisibility: .visible, presenting: selectedUser) { user in
            Button(L10n.unblock) {
                Task { await viewModel.unblock(user) }
            }
        } message: { _ in
            Text(L10n.thisAllowsYouToSeeEachOtherSContentAgainYourPreviousFriendshipWonTBeRestored)
        }
        .alert(L10n.couldnTUpdateBlockedUsers, isPresented: Binding(
            get: { viewModel.errorMessage != nil && !viewModel.users.isEmpty },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {} message: { Text(viewModel.errorMessage ?? "") }
    }
}
