import SwiftUI

struct FeedView: View {
    private let container: AppContainer
    @StateObject private var viewModel: FeedViewModel

    init(container: AppContainer) {
        self.container = container
        _viewModel = StateObject(
            wrappedValue: FeedViewModel(
                sessionStore: container.sessionStore,
                cloudKitSyncService: container.cloudKitSyncService,
                feedRepository: container.feedRepository,
                friendRepository: container.friendRepository,
                userRepository: container.userRepository,
                placeRepository: container.placeRepository,
                placeReviewRepository: container.placeReviewRepository
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
            } else if viewModel.feedItems.isEmpty {
                EmptyStateView(
                    title: "No New Places Yet",
                    message: "When you or your friends add new restaurant reviews, they will show up here.",
                    systemImage: "bell.slash"
                )
            } else {
                List(viewModel.feedItems) { item in
                    NavigationLink {
                        PlaceDetailView(container: container, place: item.place)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.title)
                                .font(.headline)

                            Text(item.subtitle)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)

                            Text(item.createdAt, style: .relative)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
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
