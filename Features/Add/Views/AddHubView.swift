import SwiftUI

struct AddHubView: View {
    @ObservedObject private var container: AppContainer
    @StateObject private var viewModel: AddHubViewModel
    @State private var activeFlow: AddHubViewModel.Flow?
    @State private var selectedPlace: Place?
    @State private var isSearchPresented = false

    init(container: AppContainer) {
        self.container = container
        _viewModel = StateObject(
            wrappedValue: AddHubViewModel(
                mapRepository: container.mapRepository,
                categoryRepository: container.categoryRepository
            )
        )
    }

    var body: some View {
        List {
            Section("Start a New Review") {
                Button {
                    activeFlow = .placeReview
                    isSearchPresented = true
                } label: {
                    Label("Add Place Review", systemImage: "mappin.circle")
                }

                Button {
                    activeFlow = .dishReview
                    isSearchPresented = true
                } label: {
                    Label("Add Dish Review", systemImage: "fork.knife.circle")
                }
            }

            Section("Recent Places") {
                if viewModel.recentPlaces.isEmpty {
                    Text("Places you create or open from Apple Maps will show up here.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.recentPlaces, id: \.id) { place in
                        Menu {
                            Button("Add Place Review") {
                                activeFlow = .placeReview
                                selectedPlace = place
                            }
                            Button("Add Dish Review") {
                                activeFlow = .dishReview
                                selectedPlace = place
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(place.name)
                                Text(place.address)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Add")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(viewModel.availableCategoryOptions) { option in
                        Button {
                            Task { await viewModel.applyCategoryFilter(option) }
                        } label: {
                            HStack {
                                Text(option.title)
                                if option == viewModel.selectedCategory {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
                .accessibilityLabel("Filter places by category")
            }
        }
        .sheet(isPresented: $isSearchPresented) {
            PlaceSearchSheet(container: container, title: activeFlow?.title ?? "Choose Place") { place in
                selectedPlace = place
            }
        }
        .sheet(
            isPresented: Binding(
                get: { selectedPlace != nil && activeFlow != nil },
                set: { if !$0 { selectedPlace = nil; activeFlow = nil } }
            ),
            onDismiss: {
                Task { await viewModel.load() }
            }
        ) {
            if let selectedPlace, let activeFlow {
                NavigationStack {
                    switch activeFlow {
                    case .placeReview:
                        AddPlaceReviewView(container: container, place: selectedPlace)
                    case .dishReview:
                        AddDishReviewView(container: container, place: selectedPlace)
                    }
                }
            }
        }
        .task {
            await viewModel.load()
        }
    }
}

#Preview {
    NavigationStack {
        AddHubView(container: PreviewAppFactory.makeContainer())
    }
}
