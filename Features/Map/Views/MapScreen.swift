import MapKit
import SwiftUI
import UIKit

struct MapScreen: View {
    @ObservedObject private var container: AppContainer
    @StateObject private var viewModel: MapScreenViewModel
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var mapSelection: MapSelection<UUID>?
    @Environment(\.openURL) private var openURL

    init(container: AppContainer) {
        self.container = container
        _viewModel = StateObject(
            wrappedValue: MapScreenViewModel(
                sessionStore: container.sessionStore,
                cloudKitSyncService: container.cloudKitSyncService,
                friendRepository: container.friendRepository,
                userRepository: container.userRepository,
                categoryRepository: container.categoryRepository,
                placeRepository: container.placeRepository,
                placeReviewRepository: container.placeReviewRepository,
                dishReviewRepository: container.dishReviewRepository,
                mapSearchService: container.mapSearchService,
                userLocationService: container.userLocationService
            )
        )
    }

    var body: some View {
        MapReader { proxy in
            GeometryReader { geometry in
                ZStack {
                    Map(position: $cameraPosition, selection: $mapSelection) {
                        UserAnnotation()

                        if let droppedPinPlace = viewModel.droppedPinPlace {
                            Annotation("Dropped Pin", coordinate: droppedPinPlace.coordinate, anchor: .bottom) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.title)
                                    .foregroundStyle(.red)
                                    .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
                            }
                        }

                        ForEach(viewModel.annotations) { annotation in
                            mapAnnotationView(for: annotation)
                        }
                    }
                    .mapStyle(mapStyle)
                    .mapFeatureSelectionDisabled { feature in
                        feature.kind != .pointOfInterest
                    }
                    .onChange(of: mapSelection) { _, selection in
                        guard let selection else {
                            viewModel.dismissPrompt()
                            return
                        }

                        Task {
                            if let placeID = selection.value {
                                viewModel.selectPlace(withID: placeID)
                            } else if let feature = selection.feature {
                                await viewModel.selectMapFeature(
                                    title: feature.title,
                                    coordinate: feature.coordinate
                                )
                            }
                        }
                    }
                    .onMapCameraChange(frequency: .onEnd) { context in
                        viewModel.handleCameraChangeDidEnd(context.region)
                    }
                    .onChange(of: viewModel.requestedCameraRegionToken) { _, _ in
                        guard let region = viewModel.requestedCameraRegion else {
                            return
                        }

                        withAnimation(.easeInOut(duration: 0.45)) {
                            cameraPosition = .region(region)
                        }
                        viewModel.clearRequestedCameraRegion()
                    }
                    .simultaneousGesture(longPressGesture(proxy: proxy))
                    .ignoresSafeArea(edges: .bottom)

                    if viewModel.isLoading && viewModel.annotations.isEmpty {
                        LoadingStateView(title: "Loading your map")
                            .background(.thinMaterial)
                    } else if let errorMessage = viewModel.errorMessage, viewModel.annotations.isEmpty {
                        ErrorStateView(message: errorMessage) {
                            Task { await viewModel.load() }
                        }
                        .background(.thinMaterial)
                    }

                    if let promptPlace = viewModel.promptPlace {
                        Color.clear
                            .contentShape(Rectangle())
                            .ignoresSafeArea()
                            .onTapGesture {
                                clearMapSelection()
                            }

                        if let point = proxy.convert(promptPlace.coordinate, to: .local) {
                            selectionPromptView(for: promptPlace)
                                .frame(width: 240)
                                .position(
                                    x: min(max(point.x, 132), geometry.size.width - 132),
                                    y: min(max(point.y + 92, 120), geometry.size.height - 120)
                                )
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }
                    }
                }
            }
        }
        .navigationTitle("Map")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $viewModel.searchText, prompt: "Search Apple Maps")
        .onChange(of: viewModel.searchText) { _, _ in
            viewModel.handleSearchTextChange()
        }
        .onSubmit(of: .search) {
            Task { await viewModel.performSearch() }
        }
        .safeAreaInset(edge: .top) {
            if !viewModel.searchResults.isEmpty {
                searchResultsView
            }
        }
        .safeAreaInset(edge: .bottom) {
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
                .padding()
            }
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

            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    viewModel.isSatelliteEnabled.toggle()
                } label: {
                    Image(systemName: viewModel.isSatelliteEnabled ? "globe.americas.fill" : "map")
                }
                .accessibilityLabel(viewModel.isSatelliteEnabled ? "Switch to standard map" : "Switch to satellite map")

                Button {
                    viewModel.isFilterPresented = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .sheet(isPresented: $viewModel.isFilterPresented) {
            MapFilterSheet(
                filterState: $viewModel.filterState,
                availablePeople: viewModel.availablePeople,
                availableCategories: viewModel.availableCategoryOptions
            ) {
                Task { await viewModel.applyFilters() }
            }
        }
        .sheet(
            isPresented: Binding(
                get: { viewModel.selectedPlace != nil },
                set: {
                    if !$0 {
                        viewModel.selectedPlace = nil
                        clearMapSelection()
                    }
                }
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

    private var mapStyle: MapStyle {
        if viewModel.isSatelliteEnabled {
            return .imagery(elevation: .realistic)
        }

        return .standard(
            elevation: .realistic,
            emphasis: .automatic,
            pointsOfInterest: .all,
            showsTraffic: false
        )
    }

    private func clearMapSelection() {
        mapSelection = nil
        viewModel.dismissPrompt()
    }

    private func selectionPromptView(for place: Place) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(place.name)
                .font(.headline)
                .lineLimit(2)

            if !place.address.isEmpty && place.address != place.name {
                Text(place.address)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Button("Details") {
                viewModel.openPromptedPlaceDetails()
            }
            .buttonStyle(.bordered)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
    }

    private func mapAnnotationView(for annotation: MapPlaceAnnotation) -> some MapContent {
        Annotation(annotation.place.name, coordinate: annotation.coordinate) {
            RatingBadgeView(rating: annotation.averageRating)
        }
        .tag(MapSelection(annotation.place.id))
    }

    private func longPressGesture(proxy: MapProxy) -> some Gesture {
        LongPressGesture(minimumDuration: 0.55, maximumDistance: 12)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
            .onEnded { value in
                guard case .second(true, let drag?) = value,
                      let coordinate = proxy.convert(drag.location, from: .local) else {
                    return
                }

                clearMapSelection()

                Task {
                    await viewModel.selectLongPressLocation(at: coordinate)
                }
            }
    }
}

#Preview {
    NavigationStack {
        MapScreen(container: PreviewAppFactory.makeContainer())
    }
}
