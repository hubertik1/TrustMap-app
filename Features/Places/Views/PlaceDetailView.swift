import SwiftUI

struct PlaceDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var container: AppContainer
    @ObservedObject private var refreshCenter: AppRefreshCenter
    @StateObject private var viewModel: PlaceDetailViewModel
    @State private var selectedReviewAuthor: UserSummary?
    private let showsDoneButton: Bool

    init(container: AppContainer, place: Place, showsDoneButton: Bool = false) {
        self.container = container
        self.refreshCenter = container.refreshCenter
        self.showsDoneButton = showsDoneButton
        _viewModel = StateObject(
            wrappedValue: PlaceDetailViewModel(
                place: place,
                refreshCenter: container.refreshCenter,
                sessionStore: container.sessionStore,
                placeRepository: container.placeRepository,
                placeReviewRepository: container.placeReviewRepository,
                dishReviewRepository: container.dishReviewRepository
            )
        )
    }

    var body: some View {
        Group {
            if viewModel.isLoading && !viewModel.hasLoadedContent {
                LoadingStateView(title: L10n.loadingPlaceDetails)
            } else if let errorMessage = viewModel.errorMessage, !viewModel.hasLoadedContent {
                ErrorStateView(message: errorMessage) {
                    Task { await viewModel.load() }
                }
            } else {
                List {
                    if let errorMessage = viewModel.errorMessage {
                        InlineErrorBanner(title: L10n.couldnTRefreshPlaceDetails, message: errorMessage) {
                            Task { await viewModel.load() }
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)
                    }

                    Section {
                        PlaceSummaryHeaderView(
                            place: viewModel.place,
                            averageRating: viewModel.averageRating,
                            categoryNames: viewModel.categoryNames,
                            contributors: viewModel.recentContributors,
                            contributorCount: viewModel.contributorCount,
                            currentUserID: viewModel.currentUserID
                        ) {
                            placeHeaderActions
                        }

                        if viewModel.canRenameCustomPlace {
                            Button(viewModel.customPlaceActionTitle) {
                                viewModel.beginRenamingCustomPlace()
                            }
                        }
                    } header: {
                        EmptyView()
                    }

                    Section {
                        if viewModel.placeReviews.isEmpty {
                            PlaceDetailEmptyStateCard(
                                title: L10n.noPlaceReviewsYet,
                                message: L10n.visiblePlaceReviewsForThisLocationWillAppearHere,
                                systemImage: "text.bubble"
                            )
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 4, trailing: 0))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        } else {
                            ForEach(viewModel.placeReviews, id: \.id) { review in
                                placeReviewRow(for: review)
                                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 4, trailing: 0))
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            }
                        }
                    } header: {
                        PlaceDetailSectionHeaderView(
                            title: L10n.placeReviews,
                            count: viewModel.placeReviews.isEmpty ? nil : viewModel.placeReviews.count,
                            titleVerticalOffset: PlaceDetailVisualSystem.Metrics.sectionHeaderTitleVerticalOffset
                        )
                    }

                    if viewModel.canAddDishReview {
                        Section {
                            if viewModel.dishReviews.isEmpty {
                                PlaceDetailEmptyStateCard(
                                    title: L10n.noDishReviewsYet,
                                    message: L10n.dishReviewsAddedForThisPlaceWillAppearHere,
                                    systemImage: "fork.knife"
                                )
                                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 4, trailing: 0))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            } else {
                                ForEach(viewModel.dishReviews, id: \.id) { review in
                                    dishReviewRow(for: review)
                                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 4, trailing: 0))
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                                }
                            }
                        } header: {
                            PlaceDetailSectionHeaderView(
                                title: L10n.dishReviews,
                                count: viewModel.dishReviews.isEmpty ? nil : viewModel.dishReviews.count,
                                actionTitle: L10n.addDish,
                                actionAccessibilityLabel: L10n.addDishReview
                            ) {
                                viewModel.isPresentingAddDishReview = true
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .trustMapReadableContent(maxWidth: TrustMapLayout.activityContentMaxWidth)
                .refreshable {
                    await viewModel.load()
                }
            }
        }
        .navigationTitle(viewModel.place.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedReviewAuthor) { author in
            if author.id == viewModel.currentUserID {
                ProfileView(container: container)
            } else {
                FriendProfileView(container: container, userID: author.id, initialUser: author)
            }
        }
        .sheet(isPresented: $viewModel.isPresentingAddPlaceReview, onDismiss: {
            Task { await viewModel.load() }
        }) {
            NavigationStack {
                AddPlaceReviewView(
                    container: container,
                    place: viewModel.place,
                    existingReview: viewModel.currentUserPlaceReview
                )
            }
            .trustMapMacSheet(width: TrustMapLayout.formMaxWidth, minHeight: 700)
        }
        .sheet(isPresented: $viewModel.isPresentingAddDishReview, onDismiss: {
            Task { await viewModel.load() }
        }) {
            NavigationStack {
                AddDishReviewView(
                    container: container,
                    place: viewModel.place,
                    placeReviewID: viewModel.currentUserPlaceReview?.id
                )
            }
            .trustMapMacSheet(width: TrustMapLayout.formMaxWidth, minHeight: 700)
        }
        .sheet(item: $viewModel.editingDishReview, onDismiss: {
            Task { await viewModel.load() }
        }) { review in
            NavigationStack {
                AddDishReviewView(
                    container: container,
                    place: viewModel.place,
                    existingReview: review
                )
            }
            .trustMapMacSheet(width: TrustMapLayout.formMaxWidth, minHeight: 700)
        }
        .task(id: refreshCenter.globalRevision) {
            await viewModel.load()
        }
        .alert(L10n.customPlaceName, isPresented: $viewModel.isPresentingCustomNameEditor) {
            TextField(L10n.sharedName, text: $viewModel.customDisplayNameDraft)

            Button(L10n.cancel, role: .cancel) {
                viewModel.customDisplayNameDraft = viewModel.place.customDisplayName ?? ""
            }

            Button(L10n.save) {
                Task { await viewModel.saveCustomPlaceName() }
            }
            .disabled(viewModel.isSavingCustomName)
        } message: {
            Text(L10n.onlyTheOriginalCreatorOfACustomMapPinCanChangeThisSharedName)
        }
        .toolbar {
            if showsDoneButton {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.done) { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var placeHeaderActions: some View {
        if AppleMapsDirectionsOpener.canOpenDirections(to: viewModel.place) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    directionsButton
                        .frame(maxWidth: .infinity)
                    placeReviewButton
                        .frame(maxWidth: .infinity)
                }

                VStack(alignment: .leading, spacing: 10) {
                    placeReviewButton
                        .frame(maxWidth: .infinity)
                    directionsButton
                        .frame(maxWidth: .infinity)
                }
            }
        } else {
            placeReviewButton
                .frame(maxWidth: .infinity)
        }
    }

    private var directionsButton: some View {
        Button {
            AppleMapsDirectionsOpener.openDirections(to: viewModel.place)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.turn.up.right.diamond")
                    .font(.system(size: PlaceDetailVisualSystem.Metrics.headerActionIconSize, weight: .semibold))

                Text(L10n.directions)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, PlaceDetailVisualSystem.Metrics.headerActionHorizontalPadding)
            .frame(maxWidth: .infinity)
            .frame(height: PlaceDetailVisualSystem.Metrics.headerActionHeight)
            .background(
                Capsule()
                    .fill(Color(uiColor: .tertiarySystemFill))
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.directions)
        .accessibilityHint(L10n.opensAppleMaps)
    }

    private var placeReviewButton: some View {
        Button {
            viewModel.beginPlaceReviewFlow()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: placeReviewButtonSystemImage)
                    .font(.system(size: PlaceDetailVisualSystem.Metrics.headerActionIconSize, weight: .semibold))

                Text(compactPlaceReviewButtonTitle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.center)
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, PlaceDetailVisualSystem.Metrics.headerActionHorizontalPadding)
            .frame(maxWidth: .infinity)
            .frame(height: PlaceDetailVisualSystem.Metrics.headerActionHeight)
            .background(
                Capsule()
                    .fill(Color.accentColor)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(placeReviewButtonAccessibilityLabel)
    }

    private var compactPlaceReviewButtonTitle: String {
        viewModel.currentUserPlaceReview == nil ? L10n.addReview : L10n.editReview
    }

    private var placeReviewButtonSystemImage: String {
        viewModel.currentUserPlaceReview == nil ? "plus.bubble" : "mappin.and.ellipse"
    }

    private var placeReviewButtonAccessibilityLabel: String {
        viewModel.currentUserPlaceReview == nil ? L10n.addPlaceReview : L10n.editPlaceReview
    }

    private func placeReviewRow(for review: PlaceReview) -> some View {
        ReviewCardView(
            review: review,
            authorName: viewModel.authorName(for: review.authorUserId),
            authorAvatarURL: review.author.avatarURL,
            photos: review.photos,
            safetyRepository: review.authorUserId == viewModel.currentUserID ? nil : container.safetyRepository,
            onEdit: review.authorUserId == viewModel.currentUserID ? { viewModel.beginPlaceReviewFlow() } : nil,
            onAuthorTap: { selectedReviewAuthor = review.author }
        )
    }

    private func dishReviewRow(for review: DishReview) -> some View {
        DishReviewRowView(
            review: review,
            authorName: viewModel.authorName(for: review.authorUserId),
            photos: review.photos,
            safetyRepository: viewModel.canEdit(review) ? nil : container.safetyRepository,
            onEdit: viewModel.canEdit(review) ? { viewModel.beginEditing(review) } : nil,
            onAuthorTap: { selectedReviewAuthor = review.author }
        )
    }
}

#Preview {
    let container = PreviewAppFactory.makeContainer()
    NavigationStack {
        PlaceDetailView(container: container, place: PreviewAppFactory.samplePlace(in: container))
    }
}
