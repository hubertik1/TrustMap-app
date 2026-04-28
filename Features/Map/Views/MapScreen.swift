import MapKit
import SwiftUI
import UIKit

struct MapScreen: View {
    @ObservedObject private var container: AppContainer
    @ObservedObject private var refreshCenter: AppRefreshCenter
    @StateObject private var viewModel: MapScreenViewModel
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var mapSelection: MapSelection<UUID>?
    @Environment(\.openURL) private var openURL

    init(container: AppContainer) {
        self.container = container
        self.refreshCenter = container.refreshCenter
        _viewModel = StateObject(
            wrappedValue: MapScreenViewModel(
                mapRepository: container.mapRepository,
                placeRepository: container.placeRepository,
                categoryRepository: container.categoryRepository,
                mapSearchService: container.mapSearchService,
                sessionStore: container.sessionStore,
                userLocationService: container.userLocationService,
                preferencesStore: container.preferencesStore
            )
        )
    }

    var body: some View {
        MapReader { proxy in
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
                    guard let region = viewModel.requestedCameraRegion else { return }

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

                if let promptContext = viewModel.promptContext {
                    Color.clear
                        .contentShape(Rectangle())
                        .ignoresSafeArea()
                        .onTapGesture {
                            clearMapSelection()
                        }

                    VStack {
                        Spacer()
                        selectionPromptView(
                            for: promptContext.place,
                            annotation: selectedAnnotation(for: promptContext.place.id)
                        )
                            .padding(.horizontal, 16)
                            .padding(.bottom, promptBottomInset)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .animation(.easeInOut(duration: 0.2), value: promptContext.id)
                }
            }
        }
        .navigationTitle("Map")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $viewModel.searchText, prompt: "Search places")
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
                categoryOptions: viewModel.availableCategoryOptions
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
        .task(id: refreshCenter.globalRevision) {
            viewModel.startLocationFlowIfNeeded()
            await viewModel.load()
        }
    }

    private var searchResultsView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.searchResults) { result in
                    Button {
                        Task { await viewModel.selectSearchResult(result) }
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

    private var promptBottomInset: CGFloat {
        viewModel.locationAccessState.message == nil ? 20 : 76
    }

    private func selectedAnnotation(for placeID: UUID) -> MapPlaceAnnotation? {
        viewModel.annotations.first(where: { $0.place.id == placeID })
    }

    private func longPressGesture(proxy: MapProxy) -> some Gesture {
        LongPressGesture(minimumDuration: 0.45)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onEnded { value in
                guard case .second(true, let drag?) = value,
                      let coordinate = proxy.convert(drag.location, from: .local) else {
                    return
                }

                Task {
                    await viewModel.selectLongPressLocation(at: coordinate)
                }
            }
    }

    @MapContentBuilder
    private func mapAnnotationView(for annotation: MapPlaceAnnotation) -> some MapContent {
        Annotation(annotation.place.displayName, coordinate: annotation.coordinate, anchor: .bottom) {
            let isSelected = viewModel.selectedAnnotationID == annotation.id

            Button {
                mapSelection = nil
                viewModel.selectPlace(withID: annotation.id)
            } label: {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(annotation.averageRating.badgeFillColor.opacity(0.28))
                            .frame(width: 40, height: 40)
                            .blur(radius: 10)
                            .offset(y: 7)
                            .transition(.opacity)
                    }

                    ZStack {
                        HStack(spacing: 6) {
                            Image(systemName: "fork.knife")
                                .font(.caption.weight(.semibold))
                            Text(RatingDisplayFormatter.rating(annotation.averageRating))
                                .font(.caption.weight(.semibold))
                        }
                        .padding(.horizontal, isSelected ? 12 : 10)
                        .padding(.vertical, isSelected ? 7 : 6)
                        .foregroundStyle(.white)
                        .background(
                            annotation.averageRating.badgeFillColor.gradient,
                            in: Capsule()
                        )
                        .overlay {
                            Capsule()
                                .strokeBorder(
                                    isSelected ? annotation.averageRating.badgeBorderColor.opacity(0.9) : annotation.averageRating.badgeBorderColor,
                                    lineWidth: 1
                                )
                        }
                    }
                }
                .scaleEffect(isSelected ? 1.08 : 1)
                .shadow(color: .black.opacity(isSelected ? 0.28 : 0.12), radius: isSelected ? 18 : 8, y: isSelected ? 10 : 4)
                .animation(.easeOut(duration: 0.18), value: isSelected)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .accessibilityLabel("Open \(annotation.place.displayName)")
            .zIndex(isSelected ? 10 : 0)
        }
        .tag(annotation.id)
    }

    private func selectionPromptView(for place: Place, annotation: MapPlaceAnnotation?) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(place.displayName)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    if let secondaryDisplayText = place.secondaryDisplayText {
                        Label {
                            Text(secondaryDisplayText)
                                .lineLimit(2)
                        } icon: {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.caption.weight(.semibold))
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 12)

                if let annotation {
                    RatingBadgeView(rating: annotation.averageRating)
                }
            }

            if let annotation {
                if !annotation.recentContributors.isEmpty {
                    ContributorSummaryRow(
                        contributors: annotation.recentContributors,
                        totalContributorCount: annotation.contributorCount,
                        currentUserID: container.sessionStore.currentUser?.id
                    )
                } else {
                    Text(reviewCountText(annotation.reviewCount))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    if isValidCoordinate(place.coordinate) {
                        directionsButton(for: place)
                    }
                    viewPlaceButton
                }

                VStack(spacing: 10) {
                    if isValidCoordinate(place.coordinate) {
                        directionsButton(for: place)
                    }
                    viewPlaceButton
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(.white.opacity(0.55), lineWidth: 1)
                }
        )
        .shadow(color: .black.opacity(0.10), radius: 18, y: 10)
    }

    private func directionsButton(for place: Place) -> some View {
        Button {
            openDirections(to: place)
        } label: {
            Label("Directions", systemImage: "arrow.triangle.turn.up.right.diamond")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .accessibilityHint("Opens Apple Maps")
    }

    private var viewPlaceButton: some View {
        Button {
            viewModel.openPromptedPlaceDetails()
        } label: {
            Label("View Place", systemImage: "arrow.right")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    private func openDirections(to place: Place) {
        let coordinate = place.coordinate
        guard isValidCoordinate(coordinate) else {
            return
        }

        let destination = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        destination.name = place.displayName
        MKMapItem.openMaps(
            with: [
                MKMapItem.forCurrentLocation(),
                destination
            ],
            launchOptions: [
                MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
            ]
        )
    }

    private func isValidCoordinate(_ coordinate: CLLocationCoordinate2D) -> Bool {
        coordinate.latitude.isFinite
            && coordinate.longitude.isFinite
            && CLLocationCoordinate2DIsValid(coordinate)
    }

    private func reviewCountText(_ count: Int) -> String {
        count == 1 ? "1 review" : "\(count) reviews"
    }
}

#Preview {
    NavigationStack {
        MapScreen(container: PreviewAppFactory.makeContainer())
    }
}
