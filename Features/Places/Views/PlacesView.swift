import SwiftUI

struct PlacesView: View {
    @ObservedObject private var container: AppContainer
    @StateObject private var viewModel: PlacesViewModel

    init(container: AppContainer) {
        self.container = container
        _viewModel = StateObject(
            wrappedValue: PlacesViewModel(
                sessionStore: container.sessionStore,
                cloudKitSyncService: container.cloudKitSyncService,
                friendRepository: container.friendRepository,
                userRepository: container.userRepository,
                categoryRepository: container.categoryRepository,
                placeRepository: container.placeRepository,
                placeReviewRepository: container.placeReviewRepository,
                dishReviewRepository: container.dishReviewRepository
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
                List(viewModel.placeItems) { item in
                    NavigationLink {
                        PlaceDetailView(container: container, place: item.place)
                    } label: {
                        PlaceListRowView(item: item)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Places")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Text(viewModel.filterSummary)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .padding()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Section("Change Category") {
                        ForEach(viewModel.availableCategoryOptions) { option in
                            Button {
                                Task { await viewModel.apply(category: option) }
                            } label: {
                                HStack {
                                    Text(option.title)
                                    if viewModel.selectedCategoryOption == option {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }

                    Section("Filter Reviews") {
                        ForEach(ReviewSourceFilterMode.allCases) { mode in
                            Button {
                                Task { await viewModel.apply(sourceFilter: mode) }
                            } label: {
                                HStack {
                                    Text(mode.displayName)
                                    if viewModel.sourceFilterMode == mode {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
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
        PlacesView(container: PreviewAppFactory.makeContainer())
    }
}
