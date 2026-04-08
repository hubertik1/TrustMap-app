import SwiftUI

struct PlacesView: View {
    @ObservedObject private var container: AppContainer
    @ObservedObject private var refreshCenter: AppRefreshCenter
    @StateObject private var viewModel: PlacesViewModel
    @State private var isFilterPresented = false
    @State private var draftCategory = PlaceCategoryOption.all

    init(container: AppContainer) {
        self.container = container
        self.refreshCenter = container.refreshCenter
        _viewModel = StateObject(
            wrappedValue: PlacesViewModel(
                mapRepository: container.mapRepository,
                categoryRepository: container.categoryRepository
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
                List {
                    ForEach(viewModel.placeItems) { item in
                        NavigationLink {
                            PlaceDetailView(container: container, place: item.place)
                        } label: {
                            PlaceListRowView(item: item)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Places")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    draftCategory = viewModel.selectedCategory
                    isFilterPresented = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .sheet(isPresented: $isFilterPresented) {
            PlacesFilterSheet(
                selectedCategory: $draftCategory,
                categoryOptions: viewModel.availableCategoryOptions
            ) {
                Task { await viewModel.selectCategory(draftCategory) }
            }
        }
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

private struct PlacesFilterSheet: View {
    @Binding var selectedCategory: PlaceCategoryOption
    let categoryOptions: [PlaceCategoryOption]
    let onApply: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Category") {
                    Picker("Show", selection: $selectedCategory) {
                        ForEach(categoryOptions) { option in
                            Text(option.title).tag(option)
                        }
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
