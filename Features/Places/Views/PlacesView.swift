import SwiftUI

struct PlacesView: View {
    @ObservedObject private var container: AppContainer
    @ObservedObject private var refreshCenter: AppRefreshCenter
    @StateObject private var viewModel: PlacesViewModel
    @State private var isFilterPresented = false
    @State private var draftFilterState = PlacesFilterState.defaultState
    @State private var selectedPlace: Place?
    @FocusState private var isSearchFieldFocused: Bool

    init(container: AppContainer) {
        self.container = container
        self.refreshCenter = container.refreshCenter
        _viewModel = StateObject(
            wrappedValue: PlacesViewModel(
                mapRepository: container.mapRepository,
                categoryRepository: container.categoryRepository,
                sessionStore: container.sessionStore,
                userLocationService: container.userLocationService
            )
        )
    }

    var body: some View {
        Group {
            if viewModel.isLoading && !viewModel.shouldShowLibraryContent {
                LoadingStateView(title: "Loading places")
            } else if let errorMessage = viewModel.errorMessage, !viewModel.shouldShowLibraryContent {
                ErrorStateView(message: errorMessage) {
                    Task { await viewModel.load() }
                }
            } else if !viewModel.shouldShowLibraryContent {
                ProductEmptyStateView(
                    title: "No places yet",
                    message: "Add your first review to start building your trusted places.",
                    systemImage: "fork.knife.circle.fill",
                    primaryActionTitle: "Add Review",
                    onPrimaryAction: {
                        container.selectedTab = .add
                    }
                )
            } else {
                placesList
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
                    viewModel.refreshLocationAvailability()
                    draftFilterState = viewModel.draftFilterStateForEditing()
                    isFilterPresented = true
                } label: {
                    PlacesFilterToolbarIcon(activeFilterCount: viewModel.activeFilterCount)
                }
                .accessibilityLabel(viewModel.filterAccessibilityLabel)
            }
        }
        .sheet(isPresented: $isFilterPresented) {
            PlacesFilterSheet(
                filterState: $draftFilterState,
                categoryOptions: viewModel.availableCategoryOptions,
                sortOptions: viewModel.availableSortOptions
            ) {
                Task {
                    await viewModel.applyFilters(draftFilterState)
                }
            }
        }
        .task(id: refreshCenter.globalRevision) {
            await viewModel.load()
        }
        .onAppear {
            viewModel.refreshLocationAvailability()
        }
        .navigationDestination(item: $selectedPlace) { place in
            PlaceDetailView(container: container, place: place)
        }
    }

    private var placesList: some View {
        List {
            searchBarRow
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 6, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            quickFiltersRow
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            if let errorMessage = viewModel.errorMessage {
                InlineErrorBanner(title: "Couldn't refresh places", message: errorMessage) {
                    Task { await viewModel.load() }
                }
                .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 10, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            if viewModel.visiblePlaceItems.isEmpty {
                emptyResultsRow
                    .listRowInsets(EdgeInsets(top: 18, leading: 16, bottom: 12, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.visiblePlaceItems) { item in
                    Button {
                        selectedPlace = item.place
                    } label: {
                        PlaceListRowView(
                            item: item,
                            currentUserID: container.sessionStore.currentUser?.id
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
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

    private var quickFiltersRow: some View {
        PlacesQuickFilterBar(
            filterState: viewModel.filterState,
            isNearestAvailable: viewModel.isNearestSortAvailable,
            onReset: {
                Task { await viewModel.resetFilters() }
            },
            onToggleMinimumRating: {
                Task { await viewModel.toggleMinimumRating(4.0) }
            },
            onSelectNearby: {
                Task { await viewModel.selectNearestSort() }
            },
            onToggleMostReviewed: {
                Task { await viewModel.toggleMostReviewed() }
            },
            onToggleMine: {
                Task { await viewModel.toggleMine() }
            }
        )
    }

    private var emptyResultsRow: some View {
        PlacesEmptyResultsView(
            title: emptyResultsTitle,
            message: emptyResultsMessage,
            showsResetFilters: viewModel.hasActiveFilters,
            onResetFilters: {
                Task { await viewModel.resetFilters() }
            }
        )
    }

    private var emptyResultsTitle: String {
        if viewModel.hasSearchText {
            let query = viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            return "No results for \"\(query)\""
        }

        return "No matching places"
    }

    private var emptyResultsMessage: String {
        viewModel.hasSearchText
            ? "Try a different search or adjust your filters."
            : "Try adjusting your filters."
    }
}

#Preview {
    NavigationStack {
        PlacesView(container: PreviewAppFactory.makeContainer())
    }
}

private struct PlacesFilterToolbarIcon: View {
    let activeFilterCount: Int

    var body: some View {
        Image(systemName: "line.3.horizontal.decrease.circle")
            .overlay(alignment: .topTrailing) {
                if activeFilterCount > 0 {
                    Text("\(activeFilterCount)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .frame(minWidth: 17, minHeight: 17)
                        .padding(.horizontal, activeFilterCount > 9 ? 3 : 0)
                        .background(Capsule().fill(Color.accentColor))
                        .offset(x: 3, y: -3)
                        .zIndex(1)
                        .accessibilityHidden(true)
                }
            }
    }
}

private struct PlacesQuickFilterBar: View {
    let filterState: PlacesFilterState
    let isNearestAvailable: Bool
    let onReset: () -> Void
    let onToggleMinimumRating: () -> Void
    let onSelectNearby: () -> Void
    let onToggleMostReviewed: () -> Void
    let onToggleMine: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                PlacesFilterChip(
                    title: "All",
                    isSelected: filterState.isDefault,
                    action: onReset
                )

                PlacesFilterChip(
                    title: "4.0+",
                    isSelected: filterState.minimumRating == 4.0,
                    action: onToggleMinimumRating
                )

                PlacesFilterChip(
                    title: "Nearby",
                    isSelected: filterState.selectedSortOption == .nearest,
                    isDisabled: !isNearestAvailable,
                    disabledHint: "Current location is unavailable.",
                    action: onSelectNearby
                )

                PlacesFilterChip(
                    title: "Most Reviewed",
                    isSelected: filterState.selectedSortOption == .mostReviewed,
                    action: onToggleMostReviewed
                )

                PlacesFilterChip(
                    title: "Mine",
                    isSelected: filterState.addedBy == .mine,
                    action: onToggleMine
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }
}

private struct PlacesFilterChip: View {
    let title: String
    let isSelected: Bool
    var isDisabled = false
    var disabledHint: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(foregroundStyle)
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(backgroundColor)
                )
                .overlay {
                    Capsule()
                        .stroke(borderColor, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.58 : 1)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint(disabledHint ?? "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var foregroundStyle: Color {
        if isDisabled {
            return .secondary
        }

        return isSelected ? .accentColor : .primary
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.14)
        }

        return Color(uiColor: .secondarySystemGroupedBackground)
    }

    private var borderColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.35)
        }

        return Color.primary.opacity(0.06)
    }
}

private struct PlacesEmptyResultsView: View {
    let title: String
    let message: String
    let showsResetFilters: Bool
    let onResetFilters: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(Color(uiColor: .tertiarySystemFill))
                )

            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if showsResetFilters {
                Button("Reset Filters", role: .destructive, action: onResetFilters)
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.bordered)
                    .padding(.top, 2)
                    .accessibilityLabel("Reset Filters")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }
}

private struct PlacesFilterSheet: View {
    @Binding var filterState: PlacesFilterState
    let categoryOptions: [PlaceCategoryOption]
    let sortOptions: [PlacesSortOption]
    let onApply: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Filters") {
                    Picker("Added by", selection: $filterState.addedBy) {
                        ForEach(PlaceOwnershipFilter.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }

                    Picker("Category", selection: $filterState.selectedCategory) {
                        ForEach(categoryOptions) { option in
                            Text(option.title).tag(option)
                        }
                    }

                    Picker("Sort by", selection: $filterState.selectedSortOption) {
                        ForEach(sortOptions) { option in
                            Text(option.title).tag(option)
                        }
                    }
                }

                Section("Minimum rating") {
                    MinimumRatingChipGrid(
                        selectedMinimumRating: $filterState.minimumRating
                    )
                }

                Section {
                    Button("Reset Filters", role: .destructive) {
                        filterState = PlacesViewModel.defaultFilterState
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
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

private enum MinimumRatingFilterOption: String, CaseIterable, Identifiable {
    case any
    case three
    case four
    case fourPointFive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .any:
            return "Any"
        case .three:
            return "3.0+"
        case .four:
            return "4.0+"
        case .fourPointFive:
            return "4.5+"
        }
    }

    var minimumRating: Double? {
        switch self {
        case .any:
            return nil
        case .three:
            return 3.0
        case .four:
            return 4.0
        case .fourPointFive:
            return 4.5
        }
    }
}

private struct MinimumRatingChipGrid: View {
    @Binding var selectedMinimumRating: Double?

    private let columns = [
        GridItem(.adaptive(minimum: 72), spacing: 8, alignment: .leading)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(MinimumRatingFilterOption.allCases) { option in
                PlacesFilterChip(
                    title: option.title,
                    isSelected: selectedMinimumRating == option.minimumRating
                ) {
                    selectedMinimumRating = option.minimumRating
                }
            }
        }
        .padding(.vertical, 2)
    }
}
