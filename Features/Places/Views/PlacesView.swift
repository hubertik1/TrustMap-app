import SwiftUI

struct PlacesView: View {
    @ObservedObject private var container: AppContainer
    @ObservedObject private var refreshCenter: AppRefreshCenter
    @StateObject private var viewModel: PlacesViewModel
    @State private var isFilterPresented = false
    @State private var draftCategory = PlaceCategoryOption.all
    @State private var draftOwnershipFilter: PlaceOwnershipFilter = .all

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
                    secondaryActionTitle: viewModel.selectedCategory != .all || viewModel.selectedOwnershipFilter != .all ? "Reset Filters" : nil,
                    onSecondaryAction: viewModel.selectedCategory != .all || viewModel.selectedOwnershipFilter != .all ? {
                        Task {
                            await viewModel.applyFilters(
                                category: .all,
                                ownershipFilter: .all
                            )
                        }
                    } : nil
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
                .refreshable {
                    await viewModel.load()
                }
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Places")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    draftCategory = viewModel.selectedCategory
                    draftOwnershipFilter = viewModel.selectedOwnershipFilter
                    isFilterPresented = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .sheet(isPresented: $isFilterPresented) {
            PlacesFilterSheet(
                selectedCategory: $draftCategory,
                selectedOwnershipFilter: $draftOwnershipFilter,
                categoryOptions: viewModel.availableCategoryOptions
            ) {
                Task {
                    await viewModel.applyFilters(
                        category: draftCategory,
                        ownershipFilter: draftOwnershipFilter
                    )
                }
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
    @Binding var selectedOwnershipFilter: PlaceOwnershipFilter
    let categoryOptions: [PlaceCategoryOption]
    let onApply: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Owner") {
                    Picker("Show", selection: $selectedOwnershipFilter) {
                        ForEach(PlaceOwnershipFilter.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                }

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
