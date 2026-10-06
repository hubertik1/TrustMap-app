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
                LoadingStateView(title: "Loading blocked users")
            } else if let error = viewModel.errorMessage, viewModel.users.isEmpty {
                ErrorStateView(message: error) { Task { await viewModel.load() } }
            } else if viewModel.users.isEmpty {
                EmptyStateView(title: "No blocked users", message: "People you block will appear here.", systemImage: "person.crop.circle.badge.checkmark")
            } else {
                List(viewModel.users) { user in
                    HStack(spacing: 12) {
                        AvatarView(name: user.displayName, avatarURL: nil, size: 44)
                        VStack(alignment: .leading) {
                            Text(user.displayName).font(.headline)
                            Text("@\(user.handle)").font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Unblock") { selectedUser = user }
                            .disabled(viewModel.unblockingID != nil)
                            .accessibilityLabel("Unblock \(user.displayName)")
                    }
                }
                .refreshable { await viewModel.load() }
            }
        }
        .navigationTitle("Blocked Users")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .confirmationDialog("Unblock \(selectedUser?.displayName ?? "user")?", isPresented: Binding(
            get: { selectedUser != nil }, set: { if !$0 { selectedUser = nil } }
        ), titleVisibility: .visible, presenting: selectedUser) { user in
            Button("Unblock") {
                Task { await viewModel.unblock(user) }
            }
        } message: { _ in
            Text("This allows you to see each other's content again. Your previous friendship won't be restored.")
        }
        .alert("Couldn't Update Blocked Users", isPresented: Binding(
            get: { viewModel.errorMessage != nil && !viewModel.users.isEmpty },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {} message: { Text(viewModel.errorMessage ?? "") }
    }
}
