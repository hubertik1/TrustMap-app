import SwiftUI

struct PlaceSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: PlaceSearchViewModel
    let title: String
    let onPlaceSelected: (Place) -> Void

    init(container: AppContainer, title: String, onPlaceSelected: @escaping (Place) -> Void) {
        self.title = title
        self.onPlaceSelected = onPlaceSelected
        _viewModel = StateObject(
            wrappedValue: PlaceSearchViewModel(
                mapSearchService: container.mapSearchService,
                placeRepository: container.placeRepository
            )
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isSearching {
                    LoadingStateView(title: "Searching places")
                } else if let errorMessage = viewModel.errorMessage {
                    ErrorStateView(message: errorMessage) {
                        Task { await viewModel.search() }
                    }
                } else if viewModel.results.isEmpty {
                    EmptyStateView(
                        title: "Search Apple Maps",
                        message: "Find the place you want to review or attach dishes to.",
                        systemImage: "magnifyingglass.circle"
                    )
                } else {
                    List(viewModel.results) { result in
                        Button {
                            Task {
                                do {
                                    let place = try await viewModel.select(result)
                                    onPlaceSelected(place)
                                    dismiss()
                                } catch {
                                    viewModel.errorMessage = AppError.wrap(error).errorDescription
                                }
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)

                                Text(result.subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.query, prompt: "Search Apple Maps")
            .onSubmit(of: .search) {
                Task { await viewModel.search() }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    PlaceSearchSheet(
        container: PreviewAppFactory.makeContainer(),
        title: "Choose Place",
        onPlaceSelected: { _ in }
    )
}
