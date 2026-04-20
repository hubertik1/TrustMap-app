import SwiftUI

struct PlaceSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: PlaceSearchViewModel
    @State private var selectionErrorMessage: String?
    let title: String
    let requiresRestaurantsCategory: Bool
    let onPlaceSelected: (Place) -> Void

    private var hasSearchQuery: Bool {
        !viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(
        container: AppContainer,
        title: String,
        requiresRestaurantsCategory: Bool = false,
        onPlaceSelected: @escaping (Place) -> Void
    ) {
        self.title = title
        self.requiresRestaurantsCategory = requiresRestaurantsCategory
        self.onPlaceSelected = onPlaceSelected
        _viewModel = StateObject(
            wrappedValue: PlaceSearchViewModel(
                mapSearchService: container.mapSearchService,
                placeRepository: container.placeRepository,
                userLocationService: container.userLocationService
            )
        )
    }

    var body: some View {
        GeometryReader { proxy in
            NavigationStack {
                Group {
                    if let errorMessage = viewModel.errorMessage,
                       viewModel.results.isEmpty,
                       !hasSearchQuery {
                        ErrorStateView(message: errorMessage) {
                            Task { await viewModel.search() }
                        }
                    } else if hasSearchQuery {
                        Color.clear
                    } else {
                        EmptyStateView(
                            title: "Search Apple Maps",
                            message: "Find the place you want to review or attach dishes to.",
                            systemImage: "magnifyingglass.circle"
                        )
                    }
                }
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $viewModel.query, prompt: "Search Apple Maps")
                .onChange(of: viewModel.query) { _, _ in
                    viewModel.handleSearchTextChange()
                }
                .onSubmit(of: .search) {
                    Task { await viewModel.search() }
                }
                .safeAreaInset(edge: .top) {
                    if !viewModel.results.isEmpty {
                        searchResultsView(
                            maxHeight: max(320, proxy.size.height - 180)
                        )
                    }
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

    private func searchResultsView(maxHeight: CGFloat) -> some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.results) { result in
                    Button {
                        selectResult(result)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(result.name)
                                .font(.headline)
                                .foregroundStyle(.primary)

                            Text(result.subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .frame(height: maxHeight, alignment: .top)
    }

    private func selectResult(_ result: PlaceSearchResult) {
        Task {
            do {
                let place = try await viewModel.select(result)
                if requiresRestaurantsCategory && !place.supportsDishReviews {
                    selectionErrorMessage = "Dish reviews are available only for places in the \(TrustMapCategory.restaurantsName) category."
                    return
                }
                onPlaceSelected(place)
                dismiss()
            } catch {
                viewModel.errorMessage = AppError.wrap(error).errorDescription
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
