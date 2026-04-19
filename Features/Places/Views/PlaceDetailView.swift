import SwiftUI

struct PlaceDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var container: AppContainer
    @ObservedObject private var refreshCenter: AppRefreshCenter
    @StateObject private var viewModel: PlaceDetailViewModel

    init(container: AppContainer, place: Place) {
        self.container = container
        self.refreshCenter = container.refreshCenter
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
                            categoryNames: viewModel.categoryNames
                        )

                        if viewModel.canRenameCustomPlace {
                            Button(viewModel.customPlaceActionTitle) {
                                viewModel.beginRenamingCustomPlace()
                            }
                        }
                    }

                    Section("Place Reviews") {
                        if viewModel.placeReviews.isEmpty {
                            Text("No visible place reviews yet.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(viewModel.placeReviews, id: \.id) { review in
                                ReviewCardView(
                                    review: review,
                                    authorName: viewModel.authorName(for: review.authorUserId),
                                    photos: review.photos
                                )
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                            }
                        }
                    }

                    Section("Photos") {
                        if viewModel.placePhotos.isEmpty {
                            Text("No photos have been added for this place yet.")
                                .foregroundStyle(.secondary)
                        } else {
                            PhotoGridView(
                                assets: viewModel.placePhotos,
                                allowsFullscreenPresentation: true
                            )
                        }
                    }

                    if viewModel.canAddDishReview {
                        Section("Dish Reviews") {
                            if viewModel.dishReviews.isEmpty {
                                Text("No visible dish reviews yet.")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(viewModel.dishReviews, id: \.id) { review in
                                    dishReviewRow(for: review)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(viewModel.place.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                Button(viewModel.placeReviewButtonTitle) {
                    viewModel.isPresentingAddPlaceReview = true
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)

                if viewModel.canAddDishReview {
                    Button("Add Dish Review") {
                        viewModel.isPresentingAddDishReview = true
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .frame(minHeight: 52)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial)
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
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }

    @ViewBuilder
    private func dishReviewRow(for review: DishReview) -> some View {
        let row = DishReviewRowView(
            review: review,
            authorName: viewModel.authorName(for: review.authorUserId),
            photo: review.photos.first,
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
