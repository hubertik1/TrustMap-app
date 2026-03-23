import SwiftUI

struct FriendsView: View {
    @StateObject private var viewModel: FriendsViewModel

    init(container: AppContainer) {
        _viewModel = StateObject(
            wrappedValue: FriendsViewModel(
                sessionStore: container.sessionStore,
                userRepository: container.userRepository,
                friendRepository: container.friendRepository
            )
        )
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                LoadingStateView(title: "Loading friends")
            } else if let errorMessage = viewModel.errorMessage {
                ErrorStateView(message: errorMessage) {
                    Task { await viewModel.load() }
                }
            } else {
                List {
                    Section("Friends") {
                        if viewModel.friends.isEmpty {
                            Text("No accepted friends yet.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(viewModel.friends, id: \.id) { friend in
                                HStack(spacing: 12) {
                                    AvatarView(name: friend.displayName)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(friend.displayName)
                                        Text(friend.bio ?? "Private friend")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .swipeActions {
                                    Button("Remove", role: .destructive) {
                                        Task { await viewModel.removeFriend(friend) }
                                    }
                                }
                            }
                        }
                    }

                    Section("Incoming Requests") {
                        if viewModel.incomingRequests.isEmpty {
                            Text("No pending incoming requests.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(viewModel.incomingRequests, id: \.id) { relation in
                                HStack {
                                    Text(viewModel.name(for: relation, incoming: true))
                                    Spacer()
                                    Button("Accept") {
                                        Task { await viewModel.accept(relation) }
                                    }
                                    Button("Reject", role: .destructive) {
                                        Task { await viewModel.reject(relation) }
                                    }
                                }
                            }
                        }
                    }

                    Section("Outgoing Requests") {
                        if viewModel.outgoingRequests.isEmpty {
                            Text("No outgoing requests.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(viewModel.outgoingRequests, id: \.id) { relation in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(viewModel.name(for: relation, incoming: false))
                                    Text("Pending")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Friends")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Find Friends") {
                    viewModel.isSearchPresented = true
                }
            }
        }
        .sheet(isPresented: $viewModel.isSearchPresented) {
            UserSearchSheet(viewModel: viewModel)
        }
        .task {
            await viewModel.load()
        }
    }
}

#Preview {
    NavigationStack {
        FriendsView(container: PreviewAppFactory.makeContainer())
    }
}
