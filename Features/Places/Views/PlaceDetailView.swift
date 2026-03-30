import SwiftUI

struct PlaceDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var container: AppContainer
    @StateObject private var viewModel: PlaceDetailViewModel

    init(container: AppContainer, place: Place) {
        self.container = container
        _viewModel = StateObject(
            wrappedValue: PlaceDetailViewModel(
                place: place,
                sessionStore: container.sessionStore,
                cloudKitSyncService: container.cloudKitSyncService,
                friendRepository: container.friendRepository,
                userRepository: container.userRepository,
                categoryRepository: container.categoryRepository,
                photoAssetRepository: container.photoAssetRepository,
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
                                    photos: viewModel.reviewPhotos[review.id] ?? [],
                                    imageDataProvider: viewModel.imageData
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
                                imageDataProvider: viewModel.imageData,
                                allowsFullscreenPresentation: true
                            )
                        }
                    }

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
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(viewModel.place.name)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                Button(viewModel.placeReviewButtonTitle) {
                    viewModel.isPresentingAddPlaceReview = true
                }
                .buttonStyle(.borderedProminent)

                Button("Add Dish Review") {
                    viewModel.isPresentingAddDishReview = true
                }
                .buttonStyle(.bordered)
            }
            .padding()
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
                AddDishReviewView(container: container, place: viewModel.place)
            }
        }
        .sheet(item: $viewModel.editingDishReview, onDismiss: {
            Task { await viewModel.load() }
        }) { review in
            NavigationStack {
                AddDishReviewView(
                    container: container,
                    place: viewModel.place,
                    existingReview: review,
                    existingPhotoData: viewModel.dishPhotoData(for: review)
                )
            }
        }
        .task {
            await viewModel.load()
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
            photo: viewModel.dishPhotos[review.id],
            imageDataProvider: viewModel.imageData
        )

        if viewModel.canEdit(review) {
            Button {
                viewModel.beginEditing(review)
            } label: {
                row
            }
            .buttonStyle(.plain)
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
