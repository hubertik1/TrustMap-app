import Combine
import MapKit
import SwiftUI
import UIKit

struct MapScreen: View {
    @ObservedObject private var container: AppContainer
    @StateObject private var viewModel: MapScreenViewModel
    @State private var cameraPosition: MapCameraPosition = .automatic
    @Environment(\.openURL) private var openURL

    init(container: AppContainer) {
        self.container = container
        _viewModel = StateObject(
            wrappedValue: MapScreenViewModel(
                sessionStore: container.sessionStore,
                friendRepository: container.friendRepository,
                userRepository: container.userRepository,
                placeRepository: container.placeRepository,
                placeReviewRepository: container.placeReviewRepository,
                mapSearchService: container.mapSearchService,
                userLocationService: container.userLocationService
            )
        )
    }

    var body: some View {
        ZStack {
            Map(position: $cameraPosition) {
                UserAnnotation()

                ForEach(viewModel.annotations, id: \.id) { annotation in
                    Annotation(annotation.place.name, coordinate: annotation.coordinate) {
                        Button {
                            viewModel.selectAnnotation(annotation)
                        } label: {
                            VStack(spacing: 4) {
                                RatingBadgeView(rating: annotation.averageRating)
                                Text(annotation.place.name)
                                    .font(.caption2)
                                    .lineLimit(1)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.thinMaterial, in: Capsule())
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .onMapCameraChange { context in
                viewModel.region = context.region
            }
            .onReceive(viewModel.$requestedCameraRegion.compactMap { $0 }) { region in
                cameraPosition = .region(region)
            }
            .ignoresSafeArea(edges: .bottom)

            if viewModel.isLoading && viewModel.annotations.isEmpty {
                LoadingStateView(title: "Loading your map")
                    .background(.thinMaterial)
            } else if let errorMessage = viewModel.errorMessage, viewModel.annotations.isEmpty {
                ErrorStateView(message: errorMessage) {
                    Task { await viewModel.load() }
                }
                .background(.thinMaterial)
            } else if viewModel.annotations.isEmpty {
                EmptyStateView(
                    title: "No Places on the Map Yet",
                    message: "Add a review or include more friends in your filters to see pins here.",
                    systemImage: "mappin.slash"
                )
                .background(.thinMaterial)
            }
        }
        .navigationTitle("Map")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $viewModel.searchText, prompt: "Search Apple Maps")
        .onSubmit(of: .search) {
            Task { await viewModel.performSearch() }
        }
        .safeAreaInset(edge: .top) {
            if !viewModel.searchResults.isEmpty {
                searchResultsView
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                if let locationMessage = viewModel.locationAccessState.message {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: "location")
                            .foregroundStyle(.secondary)

                        Text(locationMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if viewModel.locationAccessState.showsSettingsAction,
                           let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                            Button("Settings") {
                                openURL(settingsURL)
                            }
                            .font(.footnote.weight(.semibold))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                Text(viewModel.filterState.summaryText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .padding()
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    viewModel.recenterOnUserLocation()
                } label: {
                    Image(systemName: "location.fill")
                }
                .accessibilityLabel("Center on my location")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.isFilterPresented = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .sheet(isPresented: $viewModel.isFilterPresented) {
            MapFilterSheet(filterState: $viewModel.filterState, availablePeople: viewModel.availablePeople) {
                Task { await viewModel.applyFilters() }
            }
        }
        .sheet(
            isPresented: Binding(
                get: { viewModel.selectedPlace != nil },
                set: { if !$0 { viewModel.selectedPlace = nil } }
            ),
            onDismiss: {
                Task { await viewModel.load() }
            }
        ) {
            if let selectedPlace = viewModel.selectedPlace {
                NavigationStack {
                    PlaceDetailView(container: container, place: selectedPlace)
                }
            }
        }
        .task {
            viewModel.startLocationFlowIfNeeded()
            await viewModel.load()
        }
    }

    private var searchResultsView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.searchResults) { result in
                    Button {
                        Task {
                            await viewModel.selectSearchResult(result)
                        }
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
        .frame(maxHeight: 240)
    }
}

#Preview {
    NavigationStack {
        MapScreen(container: PreviewAppFactory.makeContainer())
    }
}
