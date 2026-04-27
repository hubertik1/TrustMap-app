import SwiftUI

struct AddHubView: View {
    @ObservedObject private var container: AppContainer
    @ObservedObject private var refreshCenter: AppRefreshCenter
    @StateObject private var viewModel: AddHubViewModel
    @State private var activeFlow: AddHubViewModel.Flow?
    @State private var selectedPlace: Place?
    @State private var selectedPlaceReview: PlaceReview?
    @State private var isPlaceSearchPresented = false
    @State private var isDishPlacePickerPresented = false
    @State private var shouldPresentPlaceReviewSearchAfterDishPicker = false

    init(container: AppContainer) {
        self.container = container
        self.refreshCenter = container.refreshCenter
        _viewModel = StateObject(
            wrappedValue: AddHubViewModel(
                sessionStore: container.sessionStore,
                placeReviewRepository: container.placeReviewRepository,
                dishReviewRepository: container.dishReviewRepository
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if let errorMessage = viewModel.errorMessage,
                   viewModel.recentPlaces.isEmpty {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 10) {
                    Button(action: presentPlaceReviewSearch) {
                        AddHubActionCard(
                            title: "Add Place Review",
                            subtitle: "Rate a place and share your experience.",
                            systemImage: "mappin.and.ellipse"
                        )
                    }
                    .buttonStyle(.plain)

                    Button(action: presentDishReviewPicker) {
                        AddHubActionCard(
                            title: "Add Dish Review",
                            subtitle: "Review a dish from a restaurant you visited.",
                            systemImage: "fork.knife"
                        )
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Recent Places")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)

                    if viewModel.recentPlaces.isEmpty {
                        Text("Places you've reviewed recently will show up here.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        RecentPlacesCard(
                            places: viewModel.recentPlaces,
                            placeReviewActionTitle: viewModel.placeReviewActionTitle(for:),
                            supportsDishReview: viewModel.isEligibleDishPlace(_:),
                            onPlaceReview: { place in
                                activeFlow = .placeReview
                                selectedPlace = place
                                selectedPlaceReview = viewModel.placeReview(for: place)
                            },
                            onDishReview: { place in
                                activeFlow = .dishReview
                                selectedPlace = place
                                selectedPlaceReview = nil
                            }
                        )
                    }
                }
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .contentMargins(.top, 8, for: .scrollContent)
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .navigationTitle("Add Review")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(
            isPresented: $isPlaceSearchPresented,
            onDismiss: {
                if selectedPlace == nil {
                    activeFlow = nil
                    selectedPlaceReview = nil
                }
            }
        ) {
            PlaceSearchSheet(
                container: container,
                title: activeFlow?.title ?? "Add Place Review",
                requiresRestaurantsCategory: false
            ) { place in
                selectedPlace = place
                selectedPlaceReview = nil
            }
        }
        .sheet(
            isPresented: $isDishPlacePickerPresented,
            onDismiss: handleDishPickerDismiss
        ) {
            DishReviewPlacePickerSheet(
                places: viewModel.eligibleDishPlaces,
                onPlaceSelected: { place in
                    activeFlow = .dishReview
                    selectedPlace = place
                    selectedPlaceReview = nil
                },
                onAddPlaceReview: {
                    shouldPresentPlaceReviewSearchAfterDishPicker = true
                }
            )
        }
        .sheet(
            isPresented: Binding(
                get: { selectedPlace != nil && activeFlow != nil },
                set: {
                    if !$0 {
                        selectedPlace = nil
                        selectedPlaceReview = nil
                        activeFlow = nil
                    }
                }
            ),
            onDismiss: {
                Task { await viewModel.load() }
            }
        ) {
            if let selectedPlace, let activeFlow {
                NavigationStack {
                    switch activeFlow {
                    case .placeReview:
                        AddPlaceReviewView(
                            container: container,
                            place: selectedPlace,
                            existingReview: selectedPlaceReview
                        )
                    case .dishReview:
                        AddDishReviewView(
                            container: container,
                            place: selectedPlace,
                            placeReviewID: viewModel.placeReviewID(for: selectedPlace)
                        )
                    }
                }
            }
        }
        .task(id: refreshCenter.globalRevision) {
            await viewModel.load()
        }
    }

    private func presentPlaceReviewSearch() {
        activeFlow = .placeReview
        selectedPlace = nil
        selectedPlaceReview = nil
        isPlaceSearchPresented = true
    }

    private func presentDishReviewPicker() {
        activeFlow = .dishReview
        selectedPlace = nil
        selectedPlaceReview = nil
        isDishPlacePickerPresented = true
    }

    private func handleDishPickerDismiss() {
        if shouldPresentPlaceReviewSearchAfterDishPicker {
            shouldPresentPlaceReviewSearchAfterDishPicker = false
            presentPlaceReviewSearch()
        } else if selectedPlace == nil {
            activeFlow = nil
        }
    }
}

private struct AddHubActionCard: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.18))

                Circle()
                    .stroke(Color.accentColor.opacity(0.24), lineWidth: 1)

                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 12)

            Image(systemName: "arrow.up.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(uiColor: .separator).opacity(0.12), lineWidth: 1)
        )
    }
}

private struct RecentPlacesCard: View {
    let places: [Place]
    let placeReviewActionTitle: (Place) -> String
    let supportsDishReview: (Place) -> Bool
    let onPlaceReview: (Place) -> Void
    let onDishReview: (Place) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(places.enumerated()), id: \.element.id) { index, place in
                Menu {
                    Button(placeReviewActionTitle(place)) {
                        onPlaceReview(place)
                    }

                    if supportsDishReview(place) {
                        Button("Add Dish Review") {
                            onDishReview(place)
                        }
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(place.displayName)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        if let secondaryDisplayText = place.secondaryDisplayText {
                            Text(secondaryDisplayText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if index < places.index(before: places.endIndex) {
                    Divider()
                        .overlay(Color(uiColor: .separator).opacity(0.25))
                        .padding(.horizontal, 16)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(uiColor: .separator).opacity(0.12), lineWidth: 1)
        )
    }
}

private struct DishReviewPlacePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @FocusState private var isSearchFieldFocused: Bool

    let places: [Place]
    let onPlaceSelected: (Place) -> Void
    let onAddPlaceReview: () -> Void

    private var hasSearchText: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var filteredPlaces: [Place] {
        let normalizedQuery = normalizedSearchText
        guard !normalizedQuery.isEmpty else {
            return places
        }

        return places.filter { place in
            searchableText(for: place).contains(normalizedQuery)
        }
    }

    private var normalizedSearchText: String {
        searchText.normalizedSearchText
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    guidanceState

                    if places.isEmpty {
                        noRestaurantsView
                    } else {
                        selectionSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(Color(uiColor: .systemBackground))
            .contentShape(Rectangle())
            .onTapGesture {
                isSearchFieldFocused = false
            }
            .navigationTitle("Add Dish Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func select(_ place: Place) {
        onPlaceSelected(place)
        dismiss()
    }

    private var guidanceState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.14))
                    .frame(width: 64, height: 64)

                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(spacing: 6) {
                Text("Rate a place first")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)

                Text("To add a dish review, first choose a place and rate it.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Add Place Review") {
                onAddPlaceReview()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 22)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }

    private var noRestaurantsView: some View {
        VStack(spacing: 8) {
            Text("No rated restaurants yet")
                .font(.headline)

            Text("Only places you've already rated in the \(TrustMapCategory.restaurantsName) category can be used for a dish review.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private func searchableText(for place: Place) -> String {
        [place.displayName, place.address]
            .joined(separator: " ")
            .normalizedSearchText
    }

    private var selectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Already rated a place?")
                    .font(.headline)

                Text("Choose one of your rated restaurants to continue with a dish review.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search rated restaurants", text: $searchText)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .focused($isSearchFieldFocused)

                if hasSearchText {
                    Button {
                        searchText = ""
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

            if filteredPlaces.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(hasSearchText ? filteredPlaces : places) { place in
                        Button {
                            select(place)
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 8) {
                                        Text(place.displayName)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                            .multilineTextAlignment(.leading)
                                    }

                                    if let secondaryDisplayText = place.secondaryDisplayText {
                                        Text(secondaryDisplayText)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                            .multilineTextAlignment(.leading)
                                    }
                                }

                                Spacer(minLength: 12)

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color(uiColor: .secondarySystemBackground).opacity(0.7))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.primary.opacity(0.04), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension String {
    var normalizedSearchText: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }
}

#Preview {
    NavigationStack {
        AddHubView(container: PreviewAppFactory.makeContainer())
    }
}
