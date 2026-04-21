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
                        PlaceDetailSectionHeaderView(title: "Place Reviews")
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
                            PlaceDetailSectionHeaderView(title: "Dish Reviews")
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
                .controlSize(.regular)
                .frame(maxWidth: .infinity)

                if viewModel.canAddDishReview {
                    Button("Add Dish Review") {
                        viewModel.isPresentingAddDishReview = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(minHeight: 48)
            .frame(maxWidth: .infinity)
            .background(.thinMaterial)
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
    private func placeReviewRow(for review: PlaceReview) -> some View {
        let row = ReviewCardView(
                                    review: review,
                                    authorName: viewModel.authorName(for: review.authorUserId),
                                    photos: review.photos,
                                    isEditable: review.authorUserId == viewModel.currentUserID
                                )

        if review.authorUserId == viewModel.currentUserID {
            Button {
                viewModel.isPresentingAddPlaceReview = true
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
