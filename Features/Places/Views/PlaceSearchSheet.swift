import SwiftUI

struct PlaceSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: PlaceSearchViewModel
    @State private var selectionErrorMessage: String?
    @FocusState private var isSearchFieldFocused: Bool
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
        NavigationStack {
            VStack(spacing: 16) {
                searchField

                content
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color(uiColor: .systemBackground))
            .contentShape(Rectangle())
            .onTapGesture {
                isSearchFieldFocused = false
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onChange(of: viewModel.query) { _, _ in
            viewModel.handleSearchTextChange()
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

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search Apple Maps", text: $viewModel.query)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($isSearchFieldFocused)
                .onSubmit {
                    Task { await viewModel.search() }
                }

            if viewModel.isSearching {
                ProgressView()
                    .controlSize(.small)
            } else if hasSearchQuery {
                Button {
                    viewModel.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    @ViewBuilder
    private var content: some View {
        if let errorMessage = viewModel.errorMessage,
           viewModel.results.isEmpty,
           !hasSearchQuery {
            inlineErrorView(message: errorMessage)
        } else if !hasSearchQuery {
            helperState
        } else if viewModel.results.isEmpty {
            searchStatusState
        } else {
            searchResultsView
        }
    }

    private var helperState: some View {
        VStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(Color(uiColor: .secondarySystemBackground))
                )

            VStack(spacing: 6) {
                Text("Search Apple Maps")
                    .font(.headline)

                Text("Find the place you want to review.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .center)
        .padding(.horizontal, 28)
    }

    @ViewBuilder
    private var searchStatusState: some View {
        if viewModel.isSearching {
            VStack(spacing: 12) {
                ProgressView()
                Text("Searching Apple Maps…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 220)
        } else {
            ContentUnavailableView.search(text: viewModel.query)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private func inlineErrorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.orange)
                .frame(width: 52, height: 52)
                .background(
                    Circle()
                        .fill(Color.orange.opacity(0.12))
                )

            Text("Something went wrong")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                Task { await viewModel.search() }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
        .padding(.horizontal, 20)
    }

    private var searchResultsView: some View {
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
            .padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
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
        title: "Add Place Review",
        onPlaceSelected: { _ in }
    )
}
