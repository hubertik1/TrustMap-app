import SwiftUI

struct AddDishReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AddDishReviewViewModel
    @State private var isPhotoSourceDialogPresented = false
    @State private var isDeleteConfirmationPresented = false
    private let showsCancelButton: Bool

    init(
        container: AppContainer,
        place: Place,
        placeReviewID: UUID? = nil,
        existingReview: DishReview? = nil,
        showsCancelButton: Bool = true
    ) {
        self.showsCancelButton = showsCancelButton
        _viewModel = StateObject(
            wrappedValue: AddDishReviewViewModel(
                place: place,
                placeReviewID: placeReviewID,
                dishReviewRepository: container.dishReviewRepository,
                categoryRepository: container.categoryRepository,
                refreshCenter: container.refreshCenter,
                preferencesStore: container.preferencesStore,
                currentUserReviewVisibility: container.sessionStore.currentUser?.reviewVisibility,
                existingReview: existingReview
            )
        )
    }

    var body: some View {
        reviewFormContainer
        .navigationTitle(viewModel.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(showsCancelButton)
        .toolbar {
            if showsCancelButton {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                if viewModel.isSaving || viewModel.isDeleting {
                    ProgressView()
                } else {
                    Button("Save") {
                        Task { await viewModel.save() }
                    }
                    .disabled(!viewModel.canSave)
                }
            }
        }
        .task {
            await viewModel.load()
        }
        .onChange(of: viewModel.didSave) { _, didSave in
            if didSave {
                dismiss()
            }
        }
        .onChange(of: viewModel.didDelete) { _, didDelete in
            if didDelete {
                dismiss()
            }
        }
        .alert(
            viewModel.lastAction.errorTitle,
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var reviewFormContainer: some View {
        if TrustMapPlatform.isMacCatalyst {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                reviewForm
                    .scrollContentBackground(.hidden)
                    .frame(maxWidth: TrustMapLayout.formMaxWidth)
            }
        } else {
            reviewForm
        }
    }

    private var reviewForm: some View {
        Form {
            Section("Place") {
                Text(viewModel.place.displayName)
                    .font(.headline)
                if let secondaryDisplayText = viewModel.place.secondaryDisplayText {
                    Text(secondaryDisplayText)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Dish Review") {
                TextField("Dish name", text: $viewModel.dishName)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Rating")
                            .font(.subheadline.weight(.medium))

                        Spacer()

                        Text("\(RatingDisplayFormatter.rating(viewModel.dishRating))/5")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    StarRatingInputView(rating: $viewModel.dishRating)
                }

                TextField("Short review (optional)", text: $viewModel.dishReviewText, axis: .vertical)
                    .lineLimit(3...5)
                TextField("Price", text: $viewModel.priceText)
                    .keyboardType(.decimalPad)

                Picker("Category", selection: $viewModel.selectedCategoryId) {
                    if viewModel.availableCategories.isEmpty {
                        Text("No active categories").tag(UUID?.none)
                    } else {
                        ForEach(viewModel.availableCategories) { category in
                            Text(category.name).tag(Optional(category.id))
                        }
                    }
                }

                if viewModel.selectedCategoryId == nil {
                    Text("Add the Restaurants category back to your active categories before saving.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Picker("Visibility", selection: $viewModel.visibility) {
                    ForEach(VisibilityStatus.allCases) { status in
                        Text(status.displayName).tag(status)
                    }
                }
            }

            Section("Photo") {
                Button {
                    isPhotoSourceDialogPresented = true
                } label: {
                    Label(photoButtonTitle, systemImage: "photo.on.rectangle.angled")
                }
                .accessibilityLabel(photoAccessibilityLabel)
                .reviewPhotoSourcePicker(
                    isPresented: $isPhotoSourceDialogPresented,
                    title: photoButtonTitle,
                    allowsMultipleSelection: false
                ) { preparedPhotos, didSkipAnyPhotos in
                    guard let photo = preparedPhotos.first else {
                        return
                    }

                    viewModel.setSelectedPhoto(photo)

                    if didSkipAnyPhotos {
                        viewModel.errorMessage = AppError.validationFailure("Some selected photos couldn't be prepared.").errorDescription
                    }
                } onError: { error in
                    viewModel.errorMessage = AppError.wrap(error).errorDescription
                }

                if !viewModel.existingPhotos.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Current Photos")
                            .font(.subheadline.weight(.medium))

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(viewModel.existingPhotos) { photo in
                                    existingPhotoThumbnail(photo)
                                }
                            }
                        }
                    }
                }

                if let image = viewModel.selectedPreviewImage {
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                        Button {
                            viewModel.removeSelectedPhoto()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .black.opacity(0.65))
                        }
                        .buttonStyle(.plain)
                        .padding(10)
                    }
                }
            }

            if viewModel.isEditing {
                Section {
                    Button(role: .destructive) {
                        isDeleteConfirmationPresented = true
                    } label: {
                        Text("Delete Dish Review")
                    }
                    .disabled(viewModel.isSaving || viewModel.isDeleting)
                    .confirmationDialog(
                        "Delete this dish review?",
                        isPresented: $isDeleteConfirmationPresented,
                        titleVisibility: .visible
                    ) {
                        Button("Delete Dish Review", role: .destructive) {
                            Task { await viewModel.deleteReview() }
                        }

                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This action can't be undone.")
                    }
                } header: {
                    Text("Danger Zone")
                }
            }
        }
    }

    private var photoButtonTitle: String {
        let hasActivePhoto = viewModel.selectedPhoto != nil || viewModel.existingPhotos.contains { photo in
            !viewModel.isExistingPhotoMarkedForRemoval(photo)
        }
        return hasActivePhoto ? "Replace Photo" : "Add Photo"
    }

    private var photoAccessibilityLabel: String {
        photoButtonTitle == "Replace Photo" ? "Replace photo" : "Add photo"
    }

    private func existingPhotoThumbnail(_ photo: PhotoAsset) -> some View {
        ZStack(alignment: .topTrailing) {
            RemotePhotoView(
                asset: photo,
                preferredVariant: .thumbnail,
                targetDisplaySize: CGSize(width: 96, height: 96)
            )
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    if viewModel.isExistingPhotoMarkedForRemoval(photo) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.black.opacity(0.45))
                            .overlay(
                                Label("Will Delete", systemImage: "trash")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                            )
                    } else if viewModel.selectedPhoto != nil {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.black.opacity(0.36))
                            .overlay(
                                Text("Will Replace")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                            )
                    }
                }

            Button {
                viewModel.toggleExistingPhotoRemoval(photo)
            } label: {
                Image(systemName: viewModel.isExistingPhotoMarkedForRemoval(photo) ? "arrow.uturn.backward.circle.fill" : "trash.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .red)
            }
            .buttonStyle(.plain)
            .padding(6)
        }
    }
}

#Preview {
    let container = PreviewAppFactory.makeContainer()
    NavigationStack {
        AddDishReviewView(container: container, place: PreviewAppFactory.samplePlace(in: container))
    }
}
