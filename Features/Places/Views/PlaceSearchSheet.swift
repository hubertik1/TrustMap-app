import SwiftUI

struct PlaceSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: PlaceSearchViewModel
    @State private var selectionErrorMessage: String?
    let title: String
    let requiresRestaurantCategory: Bool
    let onPlaceSelected: (Place) -> Void

    init(
        container: AppContainer,
        title: String,
        requiresRestaurantCategory: Bool = false,
        onPlaceSelected: @escaping (Place) -> Void
    ) {
        self.title = title
        self.requiresRestaurantCategory = requiresRestaurantCategory
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
                                    if requiresRestaurantCategory && !place.supportsDishReviews {
                                        selectionErrorMessage = "Dish reviews are available only for places in the Restaurant category."
                                        return
                                    }
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
            .alert("Can't Add Dish Review", isPresented: Binding(
                get: { selectionErrorMessage != nil },
                set: { if !$0 { selectionErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { selectionErrorMessage = nil }
            } message: {
                Text(selectionErrorMessage ?? "")
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
