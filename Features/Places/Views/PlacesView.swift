import SwiftUI

struct PlacesView: View {
    @ObservedObject private var container: AppContainer
    @ObservedObject private var refreshCenter: AppRefreshCenter
    @StateObject private var viewModel: PlacesViewModel
    @State private var isFilterPresented = false
    @State private var draftFilterState = MapFilterState(selectedCategory: .all)
    @State private var selectedPlace: Place?
    @FocusState private var isSearchFieldFocused: Bool

    init(container: AppContainer) {
        self.container = container
        self.refreshCenter = container.refreshCenter
        _viewModel = StateObject(
            wrappedValue: PlacesViewModel(
                mapRepository: container.mapRepository,
                categoryRepository: container.categoryRepository,
                sessionStore: container.sessionStore
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
                ProductEmptyStateView(
                    title: "No places yet",
                    message: "Add your first review or change the filters to see more places.",
                    systemImage: "fork.knife.circle.fill",
                    primaryActionTitle: "Add Review",
                    onPrimaryAction: {
                        container.selectedTab = .add
                    },
                    secondaryActionTitle: viewModel.filterState != PlacesViewModel.defaultFilterState ? "Reset Filters" : nil,
                    onSecondaryAction: viewModel.filterState != PlacesViewModel.defaultFilterState ? {
                        Task {
                            await viewModel.applyFilters(PlacesViewModel.defaultFilterState)
                        }
                    } : nil
                )
            } else {
                List {
                    searchBarRow
                        .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 6, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)

                    if viewModel.visiblePlaceItems.isEmpty {
                        ContentUnavailableView.search(text: viewModel.searchText)
                            .listRowInsets(EdgeInsets(top: 18, leading: 20, bottom: 12, trailing: 20))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    } else {
                        ForEach(viewModel.visiblePlaceItems) { item in
                            Button {
                                selectedPlace = item.place
                            } label: {
                                PlaceListRowView(item: item)
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.immediately)
                .onTapGesture {
                    isSearchFieldFocused = false
                }
                .refreshable {
                    await viewModel.load()
                }
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .onTapGesture {
            isSearchFieldFocused = false
        }
        .navigationTitle("Places")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    draftFilterState = viewModel.filterState
                    isFilterPresented = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .sheet(isPresented: $isFilterPresented) {
            PlacesFilterSheet(
                filterState: $draftFilterState,
                categoryOptions: viewModel.availableCategoryOptions
            ) {
                Task {
                    await viewModel.applyFilters(draftFilterState)
                }
            }
        }
        .task(id: refreshCenter.globalRevision) {
            await viewModel.load()
        }
        .navigationDestination(item: $selectedPlace) { place in
            PlaceDetailView(container: container, place: place)
        }
    }

    private var searchBarRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search places", text: $viewModel.searchText)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .focused($isSearchFieldFocused)

            if viewModel.hasSearchText {
                Button {
                    viewModel.searchText = ""
                    isSearchFieldFocused = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(uiColor: .separator).opacity(0.12), lineWidth: 1)
        }
    }
}

#Preview {
    NavigationStack {
        PlacesView(container: PreviewAppFactory.makeContainer())
    }
}

private struct PlacesFilterSheet: View {
    @Binding var filterState: MapFilterState
    let categoryOptions: [PlaceCategoryOption]
    let onApply: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Filters") {
                    Picker("Added by", selection: $filterState.selectedOwnershipFilter) {
                        ForEach(PlaceOwnershipFilter.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }

                    Picker("Category", selection: $filterState.selectedCategory) {
                        ForEach(categoryOptions) { option in
                            Text(option.title).tag(option)
                        }
                    }
                }

                Section("Rating Range") {
                    Stepper("Minimum Rating: \(filterState.minimumRating)", value: $filterState.minimumRating, in: 1...filterState.maximumRating)
                    Stepper("Maximum Rating: \(filterState.maximumRating)", value: $filterState.maximumRating, in: filterState.minimumRating...5)
                }

                Section {
                    Button("Reset Filters", role: .destructive) {
                        filterState = PlacesViewModel.defaultFilterState
                    }
                }
            }
            .navigationTitle("Places Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        onApply()
                        dismiss()
                    }
                }
            }
        }
    }
}
