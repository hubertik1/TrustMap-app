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
        .navigationTitle("Add")
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
                title: activeFlow?.title ?? "Choose Place",
                requiresRestaurantCategory: false
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
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 46, height: 46)
                .background(
                    Circle()
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                )

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
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
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
                        Text(place.name)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text(place.address)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
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
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
        )
    }
}

private struct DishReviewPlacePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

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
            Group {
                if places.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "fork.knife.circle")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)

                        Text("You need to review a place before adding a dish review.")
                            .font(.body.weight(.medium))
                            .multilineTextAlignment(.center)

                        Button("Add Place Review") {
                            onAddPlaceReview()
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(24)
                } else {
                    dishPlacesList
                }
            }
            .navigationTitle("Add Dish Review")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search your reviewed places")
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

    private var dishPlacesList: some View {
        Group {
            if filteredPlaces.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                List(filteredPlaces) { place in
                    Button {
                        select(place)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(place.name)
                                .font(.headline)
                                .foregroundStyle(.primary)

                            Text(place.address)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func searchableText(for place: Place) -> String {
        [place.name, place.address]
            .joined(separator: " ")
            .normalizedSearchText
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
