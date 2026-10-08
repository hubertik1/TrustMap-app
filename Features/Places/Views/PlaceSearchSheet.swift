import SwiftUI

struct PlaceSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: PlaceSearchViewModel
    @State private var selectionErrorMessage: String?
    @FocusState private var isSearchFieldFocused: Bool
    let title: String
    let requiresRestaurantsCategory: Bool
    let suggestedPlaces: [Place]
    let suggestedSectionTitle: String
    let onPlaceSelected: (Place) -> Void

    private var hasSearchQuery: Bool {
        !viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var eligibleSuggestedPlaces: [Place] {
        guard requiresRestaurantsCategory else {
            return suggestedPlaces
        }

        return suggestedPlaces.filter(\.supportsDishReviews)
    }

    init(
        container: AppContainer,
        title: String,
        requiresRestaurantsCategory: Bool = false,
        suggestedPlaces: [Place] = [],
        suggestedSectionTitle: String = L10n.recentPlaces,
        onPlaceSelected: @escaping (Place) -> Void
    ) {
        self.title = title
        self.requiresRestaurantsCategory = requiresRestaurantsCategory
        self.suggestedPlaces = suggestedPlaces
        self.suggestedSectionTitle = suggestedSectionTitle
        self.onPlaceSelected = onPlaceSelected
        _viewModel = StateObject(
            wrappedValue: PlaceSearchViewModel(
                mapSearchService: container.mapSearchService,
                placeRepository: container.placeRepository,
                userLocationService: container.userLocationService
            )
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                searchField

                content
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color(uiColor: .systemBackground))
            .contentShape(Rectangle())
            .onTapGesture {
                isSearchFieldFocused = false
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.close) { dismiss() }
                }
            }
        }
        .onChange(of: viewModel.query) { _, _ in
            viewModel.handleSearchTextChange()
        }
        .alert(L10n.canTAddDishReview, isPresented: Binding(
            get: { selectionErrorMessage != nil },
            set: { if !$0 { selectionErrorMessage = nil } }
        )) {
            Button(L10n.ok, role: .cancel) { selectionErrorMessage = nil }
        } message: {
            Text(selectionErrorMessage ?? "")
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(L10n.searchPlaces, text: $viewModel.query)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($isSearchFieldFocused)
                .onSubmit {
                    Task { await viewModel.search() }
                }

            if viewModel.isSearching {
                ProgressView()
                    .controlSize(.small)
            } else if hasSearchQuery {
                Button {
                    viewModel.query = ""
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
    }

    @ViewBuilder
    private var content: some View {
        if !hasSearchQuery {
            if eligibleSuggestedPlaces.isEmpty {
                if let errorMessage = viewModel.errorMessage, viewModel.results.isEmpty {
                    inlineErrorView(message: errorMessage)
                } else {
                    helperState
                }
            } else {
                suggestedPlacesView
            }
        } else if let errorMessage = viewModel.errorMessage, viewModel.results.isEmpty {
            inlineErrorView(message: errorMessage)
        } else if viewModel.results.isEmpty {
            searchStatusState
        } else {
            searchResultsView
        }
    }

    private var helperState: some View {
        VStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(Color(uiColor: .secondarySystemBackground))
                )

            VStack(spacing: 6) {
                Text(L10n.searchPlaces)
                    .font(.headline)

                Text(L10n.findThePlaceYouWantToReview)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .center)
        .padding(.horizontal, 28)
    }

    private var suggestedPlacesView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(suggestedSectionTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)

                LazyVStack(spacing: 8) {
                    ForEach(eligibleSuggestedPlaces) { place in
                        Button {
                            selectSuggestedPlace(place)
                        } label: {
                            placeRow(
                                title: place.displayName,
                                subtitle: place.secondaryDisplayText
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text(accessibilityLabel(for: place)))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private var searchStatusState: some View {
        if viewModel.isSearching {
            VStack(spacing: 12) {
                ProgressView()
                Text(L10n.searchingPlaces)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 220)
        } else {
            ContentUnavailableView.search(text: viewModel.query)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private func inlineErrorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.orange)
                .frame(width: 52, height: 52)
                .background(
                    Circle()
                        .fill(Color.orange.opacity(0.12))
                )

            Text(L10n.somethingWentWrong)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(L10n.tryAgain) {
                Task { await viewModel.search() }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
        .padding(.horizontal, 20)
    }

    private var searchResultsView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if let errorMessage = viewModel.errorMessage {
                    InlineErrorBanner(title: L10n.couldnTSearchPlaces, message: errorMessage) {
                        Task { await viewModel.search() }
                    }
                    .padding(.bottom, 4)
                }

                ForEach(viewModel.results) { result in
                    Button {
                        selectResult(result)
                    } label: {
                        placeRow(
                            title: result.name,
                            subtitle: result.subtitle
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(accessibilityLabel(title: result.name, subtitle: result.subtitle)))
                }
            }
            .padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
    }

    private func placeRow(title: String, subtitle: String?) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                if let subtitle,
                   !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(subtitle)
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

    private func selectResult(_ result: PlaceSearchResult) {
        Task {
            do {
                let place = try await viewModel.select(result)
                if requiresRestaurantsCategory && !place.supportsDishReviews {
                    selectionErrorMessage = L10n.dishReviewsAreAvailableOnlyForPlacesInTheValueCategory(L10n.restaurants)
                    return
                }
                onPlaceSelected(place)
                dismiss()
            } catch {
                viewModel.errorMessage = AppError.wrap(error).errorDescription
            }
        }
    }

    private func selectSuggestedPlace(_ place: Place) {
        if requiresRestaurantsCategory && !place.supportsDishReviews {
            selectionErrorMessage = L10n.dishReviewsAreAvailableOnlyForPlacesInTheValueCategory(L10n.restaurants)
            return
        }

        onPlaceSelected(place)
        dismiss()
    }

    private func accessibilityLabel(for place: Place) -> String {
        accessibilityLabel(title: place.displayName, subtitle: place.secondaryDisplayText)
    }

    private func accessibilityLabel(title: String, subtitle: String?) -> String {
        guard let subtitle,
              !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return title
        }

        return "\(title), \(subtitle)"
    }
}

#Preview {
    PlaceSearchSheet(
        container: PreviewAppFactory.makeContainer(),
        title: L10n.addPlaceReview,
        onPlaceSelected: { _ in }
    )
}
