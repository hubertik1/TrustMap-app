import SwiftUI

struct UserSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: FriendsViewModel

    var body: some View {
        NavigationStack {
            List(viewModel.searchResults, id: \.id) { user in
                Button {
                    Task { await viewModel.sendRequest(to: user) }
                } label: {
                    HStack(spacing: 12) {
                        AvatarView(name: user.displayName)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.displayName)
                                .foregroundStyle(.primary)
                            Text(user.bio ?? "Private TrustMap user")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .overlay {
                if viewModel.searchResults.isEmpty && !viewModel.searchQuery.isEmpty {
                    EmptyStateView(
                        title: "No Users Found",
                        message: "Try another name or invite the person into TrustMap later.",
                        systemImage: "person.crop.circle.badge.questionmark"
                    )
                }
            }
            .navigationTitle("Find Friends")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.searchQuery, prompt: "Search users")
            .onSubmit(of: .search) {
                Task { await viewModel.searchUsers() }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

private struct UserSearchSheetPreviewHost: View {
    @StateObject private var viewModel: FriendsViewModel

    init() {
        let container = PreviewAppFactory.makeContainer()
        _viewModel = StateObject(
            wrappedValue: FriendsViewModel(
                sessionStore: container.sessionStore,
                userRepository: container.userRepository,
                friendRepository: container.friendRepository
            )
        )
    }

    var body: some View {
        UserSearchSheet(viewModel: viewModel)
            .task {
                await viewModel.load()
                viewModel.searchQuery = "a"
                await viewModel.searchUsers()
            }
    }
}

#Preview {
    UserSearchSheetPreviewHost()
}
