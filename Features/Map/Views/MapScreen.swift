import MapKit
import SwiftUI
import UIKit

struct MapScreen: View {
    @ObservedObject private var container: AppContainer
    @ObservedObject private var refreshCenter: AppRefreshCenter
    @StateObject private var viewModel: MapScreenViewModel
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var mapSelection: MapSelection<UUID>?
    @State private var isPhoneSearchPresented = false
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
        GeometryReader { geometry in
            if isRenderableMapSize(geometry.size) {
                MapReader { proxy in
                    ZStack(alignment: .topLeading) {
                Map(position: $cameraPosition, selection: $mapSelection) {
                    UserAnnotation()

                    if let searchResult = viewModel.searchResultMarker {
                        if let mapItem = searchResult.mapItem {
                            Marker(item: mapItem)
                                .annotationTitles(.visible)
                        } else {
                            Marker(
                                searchResult.place.displayName,
                                systemImage: "mappin",
                                coordinate: searchResult.coordinate
                            )
                            .tint(Color.accentColor)
                            .annotationTitles(.visible)
                        }
                    }

                    if let droppedPinPlace = viewModel.droppedPinPlace {
                        Annotation(L10n.droppedPin, coordinate: droppedPinPlace.coordinate, anchor: .bottom) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.title)
                                .foregroundStyle(.red)
                                .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
                        }
                    }

                    ForEach(viewModel.annotations) { annotation in
                        if annotation.place.id != viewModel.searchResultMarker?.id {
                            mapAnnotationView(for: annotation)
                        }
                    }
                }
                .mapStyle(mapStyle)
                .mapFeatureSelectionDisabled { feature in
                    feature.kind != .pointOfInterest
                }
                .onChange(of: mapSelection) { _, selection in
                    guard let selection else {
                        // MapKit can clear its selection while the map is moving.
                        // Dismiss our place card only after an explicit map tap.
                        return
                    }

                    Task {
                        if let placeID = selection.value {
                            await viewModel.selectPlace(withID: placeID)
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
                .simultaneousGesture(
                    mapDismissGesture,
                    including: isPlaceSelectionPresented ? .all : .subviews
                )
                // Keep the map behind the floating phone navigation and search controls.
                .ignoresSafeArea(edges: TrustMapPlatform.isMacCatalyst ? .bottom : .all)

                if !isPlaceSelectionPresented && MapStatusOverlayVisibility.shouldShowFullScreenLoading(
                    isLoading: viewModel.isLoading,
                    hasVisibleAnnotationsInCurrentViewport: viewModel.hasVisibleMapContentInCurrentViewport
                ) {
                    LoadingStateView(title: L10n.loadingYourMap)
                        .background(.thinMaterial)
                } else if !isPlaceSelectionPresented && MapStatusOverlayVisibility.shouldShowFullScreenError(
                    errorMessage: viewModel.errorMessage,
                    hasVisibleAnnotationsInCurrentViewport: viewModel.hasVisibleMapContentInCurrentViewport
                ), let errorMessage = viewModel.errorMessage {
                    ErrorStateView(message: errorMessage) {
                        Task { await viewModel.load() }
                    }
                    .background(.thinMaterial)
                }

                if shouldShowMapStatusOverlay {
                    VStack {
                        mapStatusOverlay
                            .frame(maxWidth: TrustMapPlatform.isMacCatalyst ? TrustMapLayout.mapSearchPanelWidth : nil)
                            .padding(.horizontal, 16)
                            .padding(.top, 12)

                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
                    .accessibilitySortPriority(1)
                }

                if TrustMapPlatform.isMacCatalyst {
                    macSearchResultsOverlay
                    macLocationAccessOverlay
                }

                if let promptContext = viewModel.promptContext {
                    Group {
                        if TrustMapPlatform.isMacCatalyst {
                            HStack {
                                Spacer(minLength: 0)
                                selectionPromptView(
                                    for: promptContext.place,
                                    annotation: selectedAnnotation(for: promptContext.place.id)
                                )
                                .frame(maxWidth: TrustMapLayout.mapInspectorWidth)
                                .padding(.top, 24)
                                .padding(.trailing, 24)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                        } else {
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
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: promptContext.id)
                }
                    }
                }
            } else {
                Color(uiColor: .systemBackground)
            }
        }
        .navigationTitle(L10n.map)
        .navigationBarTitleDisplayMode(.inline)
        .modifier(PhoneMapSearchModifier(
            searchText: $viewModel.searchText,
            isPresented: $isPhoneSearchPresented
        ))
        .onChange(of: viewModel.searchText) { _, _ in
            viewModel.handleSearchTextChange()
        }
        .onSubmit(of: .search) {
            Task { await viewModel.performSearch() }
        }
        .safeAreaInset(edge: .top) {
            if !TrustMapPlatform.isMacCatalyst && !viewModel.searchResults.isEmpty {
                searchResultsView
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !TrustMapPlatform.isMacCatalyst && viewModel.locationAccessState.message != nil {
                locationAccessBanner
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
                .accessibilityLabel(L10n.centerOnMyLocation)
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    viewModel.isSatelliteEnabled.toggle()
                } label: {
                    Image(systemName: viewModel.isSatelliteEnabled ? "globe.americas.fill" : "map")
                }
                .accessibilityLabel(viewModel.isSatelliteEnabled ? L10n.switchToStandardMap : L10n.switchToSatelliteMap)

                Button {
                    viewModel.isFilterPresented = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
                .accessibilityLabel(viewModel.hasActiveFilters ? L10n.filtersActive : L10n.filters)
            }

            if TrustMapPlatform.isMacCatalyst {
                ToolbarItem(placement: .topBarTrailing) {
                    macSearchField
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
            .trustMapMacSheet(width: 480, minHeight: 520)
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
            )
        ) {
            if let selectedPlace = viewModel.selectedPlace {
                NavigationStack {
                    PlaceDetailView(container: container, place: selectedPlace, showsDoneButton: true)
                }
                .id(selectedPlace.id)
                .trustMapMacSheet(width: 780, minHeight: 700)
            }
        }
        .task(id: refreshCenter.mapRevision) {
            viewModel.startLocationFlowIfNeeded()
            await viewModel.load(resetPinCache: true)
        }
        .onChange(of: refreshCenter.mapPinRefresh) { _, refresh in
            guard let refresh else { return }
            Task {
                await viewModel.refreshPin(placeID: refresh.placeID)
            }
        }
    }

    private func isRenderableMapSize(_ size: CGSize) -> Bool {
        size.width > 2 && size.height > 2
    }

    private var searchResultsView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.searchResults) { result in
                    Button {
                        isPhoneSearchPresented = false
                        clearMapSelection()
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

    private var macSearchField: some View {
        MacMapSearchTextField(text: $viewModel.searchText) {
            Task { await viewModel.performSearch() }
        }
        .frame(width: 310, height: 34)
        .fixedSize()
    }

    @ViewBuilder
    private var macSearchResultsOverlay: some View {
        if !viewModel.searchResults.isEmpty {
            searchResultsView
                .frame(width: TrustMapLayout.mapSearchPanelWidth)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.45), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.10), radius: 18, y: 10)
                .padding(.top, 18)
                .padding(.trailing, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    @ViewBuilder
    private var macLocationAccessOverlay: some View {
        if viewModel.locationAccessState.message != nil {
            VStack {
                Spacer()

                locationAccessBanner
                    .frame(maxWidth: TrustMapLayout.mapSearchPanelWidth)
                    .padding(.leading, 18)
                    .padding(.bottom, 18)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var locationAccessBanner: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "location")
                .foregroundStyle(.secondary)

            Text(viewModel.locationAccessState.message ?? "")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if viewModel.locationAccessState.showsSettingsAction,
               let settingsURL = TrustMapSystemSettings.appSettingsURL {
                Button(L10n.settings) {
                    openURL(settingsURL)
                }
                .font(.footnote.weight(.semibold))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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

    private var shouldShowMapStatusOverlay: Bool {
        MapStatusOverlayVisibility.shouldShowStatusOverlay(
            isPromptPresented: viewModel.promptContext != nil || viewModel.searchResultMarker != nil,
            isDroppedPinPresented: viewModel.droppedPinPlace != nil,
            hasSearchResults: !viewModel.searchResults.isEmpty,
            searchText: viewModel.searchText,
            errorMessage: viewModel.errorMessage,
            hasLoadedMapPlaces: viewModel.hasLoadedMapPlaces,
            isLoading: viewModel.isLoading,
            hasVisibleAnnotationsInCurrentViewport: viewModel.hasVisibleMapContentInCurrentViewport
        )
    }

    @ViewBuilder
    private var mapStatusOverlay: some View {
        if MapStatusOverlayVisibility.shouldShowRefreshErrorBanner(
            errorMessage: viewModel.errorMessage,
            hasVisibleAnnotationsInCurrentViewport: viewModel.hasVisibleMapContentInCurrentViewport
        ), let errorMessage = viewModel.errorMessage {
            InlineErrorBanner(title: L10n.couldnTRefreshMap, message: errorMessage) {
                Task { await viewModel.load() }
            }
        } else if viewModel.hasActiveFilters {
            MapStatusCard(
                title: L10n.noPlacesMatchYourFilters,
                message: L10n.tryChangingFiltersOrMovingTheMap,
                actionTitle: L10n.filters
            ) {
                viewModel.isFilterPresented = true
            }
        } else {
            MapStatusCard(
                title: L10n.noReviewedPlacesInThisAreaYet,
                message: L10n.moveTheMapOrAddAReview
            )
        }
    }

    private func clearMapSelection() {
        mapSelection = nil
        viewModel.dismissPrompt()
    }

    private var isPlaceSelectionPresented: Bool {
        viewModel.promptContext != nil
            || viewModel.searchResultMarker != nil
            || viewModel.droppedPinPlace != nil
            || viewModel.selectedAnnotationID != nil
    }

    private var mapDismissGesture: some Gesture {
        // Let MapKit handle pan, pinch, and double-tap zoom alongside this gesture.
        TapGesture(count: 2)
            .exclusively(before: TapGesture(count: 1))
            .onEnded { value in
                guard case .second = value, isPlaceSelectionPresented else { return }
                clearMapSelection()
            }
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
                Task {
                    await viewModel.selectPlace(withID: annotation.id)
                }
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
            .accessibilityLabel(L10n.openValue(String(describing: annotation.place.displayName)))
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
                    if AppleMapsDirectionsOpener.canOpenDirections(to: place) {
                        directionsButton(for: place)
                    }
                    viewPlaceButton
                }

                VStack(spacing: 10) {
                    if AppleMapsDirectionsOpener.canOpenDirections(to: place) {
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
            AppleMapsDirectionsOpener.openDirections(to: place)
        } label: {
            Label(L10n.directions, systemImage: "arrow.triangle.turn.up.right.diamond")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .accessibilityHint(L10n.opensAppleMaps)
    }

    private var viewPlaceButton: some View {
        Button {
            viewModel.openPromptedPlaceDetails()
        } label: {
            Label(L10n.viewPlace, systemImage: "arrow.right")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    private func reviewCountText(_ count: Int) -> String {
        L10n.reviewCount(count)
    }
}

private struct PhoneMapSearchModifier: ViewModifier {
    @Binding var searchText: String
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        if TrustMapPlatform.isMacCatalyst {
            content
        } else {
            content
                .searchable(
                    text: $searchText,
                    isPresented: $isPresented,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: L10n.searchPlaces
                )
                // Hide the full-width navigation material and its separator while
                // retaining the system backgrounds on individual controls.
                .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}

private struct MacMapSearchTextField: UIViewRepresentable {
    @Binding var text: String
    let onSubmit: () -> Void

    func makeUIView(context: Context) -> UISearchTextField {
        let textField = UISearchTextField(frame: .zero)
        textField.delegate = context.coordinator
        textField.placeholder = L10n.searchPlaces
        textField.returnKeyType = .search
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .words
        textField.clearButtonMode = .whileEditing
        textField.adjustsFontForContentSizeCategory = true
        textField.font = UIFont.preferredFont(forTextStyle: .body)
        textField.backgroundColor = UIColor.secondarySystemFill.withAlphaComponent(0.92)
        textField.layer.cornerCurve = .continuous
        textField.layer.cornerRadius = 17
        textField.clipsToBounds = true
        textField.addTarget(
            context.coordinator,
            action: #selector(Coordinator.textDidChange(_:)),
            for: .editingChanged
        )
        return textField
    }

    func updateUIView(_ textField: UISearchTextField, context: Context) {
        if textField.text != text {
            textField.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSubmit: onSubmit)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        private var text: Binding<String>
        private let onSubmit: () -> Void

        init(text: Binding<String>, onSubmit: @escaping () -> Void) {
            self.text = text
            self.onSubmit = onSubmit
        }

        @objc func textDidChange(_ textField: UITextField) {
            text.wrappedValue = textField.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            onSubmit()
            return true
        }
    }
}

private struct MapStatusCard: View {
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "mappin.slash")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
                .background(Color(uiColor: .tertiarySystemFill), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .font(.footnote.weight(.semibold))
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.accentColor)
                        .padding(.top, 2)
                        .accessibilityLabel(actionTitle)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.45), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
    }
}

#Preview {
    NavigationStack {
        MapScreen(container: PreviewAppFactory.makeContainer())
    }
}
