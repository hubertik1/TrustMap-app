import SwiftUI

struct PlaceDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var container: AppContainer
    @ObservedObject private var refreshCenter: AppRefreshCenter
    @StateObject private var viewModel: PlaceDetailViewModel
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
            if viewModel.isLoading {
                LoadingStateView(title: "Loading place details")
            } else if let errorMessage = viewModel.errorMessage {
                ErrorStateView(message: errorMessage) {
                    Task { await viewModel.load() }
                }
            } else {
                List {
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
                                title: "No place reviews yet",
                                message: "Visible place reviews for this location will appear here.",
                                systemImage: "text.bubble"
                            )
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                            .listRowBackground(Color.clear)
                        } else {
                            ForEach(viewModel.placeReviews, id: \.id) { review in
                                placeReviewRow(for: review)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                                    .listRowBackground(Color.clear)
                            }
                        }
                    } header: {
                        PlaceDetailSectionHeaderView(
                            title: "Place Reviews",
                            count: viewModel.placeReviews.isEmpty ? nil : viewModel.placeReviews.count
                        )
                    }

                    if viewModel.canAddDishReview {
                        Section {
                            if viewModel.dishReviews.isEmpty {
                                PlaceDetailEmptyStateCard(
                                    title: "No dish reviews yet",
                                    message: "Dish reviews added for this place will appear here.",
                                    systemImage: "fork.knife"
                                )
                                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                                .listRowBackground(Color.clear)
                            } else {
                                ForEach(viewModel.dishReviews, id: \.id) { review in
                                    dishReviewRow(for: review)
                                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                                        .listRowBackground(Color.clear)
                                }
                            }
                        } header: {
                            PlaceDetailSectionHeaderView(
                                title: "Dish Reviews",
                                count: viewModel.dishReviews.isEmpty ? nil : viewModel.dishReviews.count,
                                actionTitle: "Add",
                                actionAccessibilityLabel: "Add Dish Review"
                            ) {
                                viewModel.isPresentingAddDishReview = true
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(viewModel.place.displayName)
        .navigationBarTitleDisplayMode(.inline)
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
        }
        .task(id: refreshCenter.globalRevision) {
            await viewModel.load()
        }
        .alert("Custom Place Name", isPresented: $viewModel.isPresentingCustomNameEditor) {
            TextField("Shared name", text: $viewModel.customDisplayNameDraft)

            Button("Cancel", role: .cancel) {
                viewModel.customDisplayNameDraft = viewModel.place.customDisplayName ?? ""
            }

            Button("Save") {
                Task { await viewModel.saveCustomPlaceName() }
            }
            .disabled(viewModel.isSavingCustomName)
        } message: {
            Text("Only the original creator of a custom map pin can change this shared name.")
        }
        .toolbar {
            if showsDoneButton {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
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
                    placeReviewButton
                }

                VStack(alignment: .leading, spacing: 10) {
                    placeReviewButton
                    directionsButton
                }
            }
        } else {
            placeReviewButton
        }
    }

    private var directionsButton: some View {
        Button {
            AppleMapsDirectionsOpener.openDirections(to: viewModel.place)
        } label: {
            Label("Directions", systemImage: "arrow.triangle.turn.up.right.diamond")
                .font(.subheadline.weight(.semibold))
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .accessibilityLabel("Directions")
        .accessibilityHint("Opens Apple Maps")
    }

    private var placeReviewButton: some View {
        Button {
            viewModel.beginPlaceReviewFlow()
        } label: {
            Label {
                Text(viewModel.placeReviewButtonTitle)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            } icon: {
                Image(systemName: viewModel.currentUserPlaceReview == nil ? "plus.bubble" : "square.and.pencil")
            }
            .font(.subheadline.weight(.semibold))
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.regular)
        .accessibilityLabel(viewModel.placeReviewButtonTitle)
    }

    @ViewBuilder
    private func placeReviewRow(for review: PlaceReview) -> some View {
        let row = ReviewCardView(
                                    review: review,
                                    authorName: viewModel.authorName(for: review.authorUserId),
                                    authorAvatarURL: review.author.avatarURL,
                                    photos: review.photos,
                                    isEditable: review.authorUserId == viewModel.currentUserID
                                )

        if review.authorUserId == viewModel.currentUserID {
            Button {
                viewModel.beginPlaceReviewFlow()
            } label: {
                row
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
        } else {
            row
        }
    }

    @ViewBuilder
    private func dishReviewRow(for review: DishReview) -> some View {
        let row = DishReviewRowView(
            review: review,
            authorName: viewModel.authorName(for: review.authorUserId),
            photos: review.photos,
            isEditable: viewModel.canEdit(review)
        )

        if viewModel.canEdit(review) {
            Button {
                viewModel.beginEditing(review)
            } label: {
                row
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
        } else {
            row
        }
    }
}

#Preview {
    let container = PreviewAppFactory.makeContainer()
    NavigationStack {
        PlaceDetailView(container: container, place: PreviewAppFactory.samplePlace(in: container))
    }
}
