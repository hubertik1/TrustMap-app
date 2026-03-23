import SwiftUI

struct FeedView: View {
    @StateObject private var viewModel: FeedViewModel

    init(container: AppContainer) {
        _viewModel = StateObject(
            wrappedValue: FeedViewModel(
                sessionStore: container.sessionStore,
                feedRepository: container.feedRepository,
                friendRepository: container.friendRepository,
                userRepository: container.userRepository
            )
        )
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                LoadingStateView(title: "Loading activity")
            } else if let errorMessage = viewModel.errorMessage {
                ErrorStateView(message: errorMessage) {
                    Task { await viewModel.load() }
                }
            } else if viewModel.activityItems.isEmpty {
                EmptyStateView(
                    title: "No Friend Activity Yet",
                    message: "Once your friends add reviews or photos, their updates will show up here.",
                    systemImage: "bell.slash"
                )
            } else {
                List(viewModel.activityItems, id: \.id) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(viewModel.title(for: item))
                            .font(.headline)
                        Text(item.createdAt, style: .relative)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Feed")
        .task {
            await viewModel.load()
        }
    }
}

#Preview {
    NavigationStack {
        FeedView(container: PreviewAppFactory.makeContainer())
    }
}
