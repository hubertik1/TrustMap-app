import SwiftUI

struct FeedView: View {
    private let container: AppContainer
    @ObservedObject private var refreshCenter: AppRefreshCenter
    @StateObject private var viewModel: FeedViewModel

    init(container: AppContainer) {
        self.container = container
        self.refreshCenter = container.refreshCenter
        _viewModel = StateObject(
            wrappedValue: FeedViewModel(
                feedRepository: container.feedRepository
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
                    message: "When you or your friends add new restaurant or dish reviews, they will show up here.",
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
        .task(id: refreshCenter.globalRevision) {
            await viewModel.load()
        }
    }
}

#Preview {
    NavigationStack {
        FeedView(container: PreviewAppFactory.makeContainer())
    }
}
