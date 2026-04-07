import SwiftUI

struct PlacesView: View {
    @ObservedObject private var container: AppContainer
    @ObservedObject private var refreshCenter: AppRefreshCenter
    @StateObject private var viewModel: PlacesViewModel

    init(container: AppContainer) {
        self.container = container
        self.refreshCenter = container.refreshCenter
        _viewModel = StateObject(
            wrappedValue: PlacesViewModel(
                mapRepository: container.mapRepository
            )
        )
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.placeItems.isEmpty {
                LoadingStateView(title: "Loading places")
            } else if let errorMessage = viewModel.errorMessage, viewModel.placeItems.isEmpty {
                ErrorStateView(message: errorMessage) {
                    Task { await viewModel.load() }
                }
            } else if viewModel.placeItems.isEmpty {
                EmptyStateView(
                    title: "No Places Yet",
                    message: "Add your first restaurant or dish review, or switch the filter to include more people.",
                    systemImage: "fork.knife.circle"
                )
            } else {
                List(viewModel.placeItems) { item in
                    NavigationLink {
                        PlaceDetailView(container: container, place: item.place)
                    } label: {
                        PlaceListRowView(item: item)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Places")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: refreshCenter.globalRevision) {
            await viewModel.load()
        }
    }
}

#Preview {
    NavigationStack {
        PlacesView(container: PreviewAppFactory.makeContainer())
    }
}
