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
                    Button(L10n.cancel) { dismiss() }
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                if viewModel.isSaving || viewModel.isDeleting {
                    ProgressView()
                } else {
                    Button(L10n.save) {
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
            Button(L10n.ok, role: .cancel) {}
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
            Section(L10n.place) {
                Text(viewModel.place.displayName)
                    .font(.headline)
                if let secondaryDisplayText = viewModel.place.secondaryDisplayText {
                    Text(secondaryDisplayText)
                        .foregroundStyle(.secondary)
                }
            }

            Section(L10n.dishReview) {
                TextField(L10n.dishName, text: $viewModel.dishName)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(L10n.rating)
                            .font(.subheadline.weight(.medium))

                        Spacer()

                        Text("\(RatingDisplayFormatter.rating(viewModel.dishRating))/5")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    StarRatingInputView(rating: $viewModel.dishRating)
                }

                TextField(L10n.shortReviewOptional, text: $viewModel.dishReviewText, axis: .vertical)
                    .lineLimit(3...5)
                HStack {
                    TextField(L10n.price, text: $viewModel.priceText)
                        .keyboardType(.decimalPad)
                        .accessibilityLabel(L10n.price)
                        .accessibilityHint(viewModel.priceCurrency.code)

                    if viewModel.isResolvingCurrency {
                        ProgressView()
                    } else {
                        Text(viewModel.priceCurrency.symbol)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(viewModel.priceCurrency.code)
                    }
                }
                .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                .alignmentGuide(.listRowSeparatorTrailing) { dimensions in dimensions.width }

                Picker(L10n.category, selection: $viewModel.selectedCategoryId) {
                    if viewModel.availableCategories.isEmpty {
                        Text(L10n.noActiveCategories).tag(UUID?.none)
                    } else {
                        ForEach(viewModel.availableCategories) { category in
                            Text(category.displayName).tag(Optional(category.id))
                        }
                    }
                }

                if viewModel.selectedCategoryId == nil {
                    Text(L10n.addTheRestaurantsCategoryBackToYourActiveCategoriesBeforeSaving)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section(L10n.photo) {
                Button {
                    isPhotoSourceDialogPresented = true
                } label: {
                    Label(photoButtonTitle, systemImage: "photo.on.rectangle.angled")
                }
                .accessibilityLabel(photoAccessibilityLabel)
                .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
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
                        viewModel.errorMessage = AppError.validationFailure(L10n.someSelectedPhotosCouldnTBePrepared).errorDescription
                    }
                } onError: { error in
                    viewModel.errorMessage = AppError.wrap(error).errorDescription
                }

                if !visibleExistingPhotos.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.currentPhotos)
                            .font(.subheadline.weight(.medium))

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(visibleExistingPhotos) { photo in
                                    existingPhotoThumbnail(photo)
                                }
                            }
                        }
                    }
                }

                if let image = viewModel.selectedPreviewImage {
                    selectedPhotoThumbnail(image)
                }
            }

            if viewModel.isEditing {
                Section {
                    Button(role: .destructive) {
                        isDeleteConfirmationPresented = true
                    } label: {
                        Text(L10n.deleteDishReview)
                    }
                    .disabled(viewModel.isSaving || viewModel.isDeleting)
                    .confirmationDialog(
                        L10n.deleteThisDishReview,
                        isPresented: $isDeleteConfirmationPresented,
                        titleVisibility: .visible
                    ) {
                        Button(L10n.deleteDishReview, role: .destructive) {
                            Task { await viewModel.deleteReview() }
                        }

                        Button(L10n.cancel, role: .cancel) {}
                    } message: {
                        Text(L10n.thisActionCanTBeUndone)
                    }
                } header: {
                    Text(L10n.dangerZone)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .trustMapDismissKeyboardOnTap()
    }

    private var visibleExistingPhotos: [PhotoAsset] {
        viewModel.existingPhotos.filter { photo in
            !viewModel.isExistingPhotoMarkedForRemoval(photo)
        }
    }

    private var photoButtonTitle: String {
        let hasActivePhoto = viewModel.selectedPhoto != nil || !visibleExistingPhotos.isEmpty
        return hasActivePhoto ? L10n.replacePhoto : L10n.addPhoto
    }

    private var photoAccessibilityLabel: String {
        photoButtonTitle == L10n.replacePhoto ? L10n.replacePhoto : L10n.addPhoto
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
                    if viewModel.selectedPhoto != nil {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.black.opacity(0.36))
                            .overlay(
                                Text(L10n.willReplace)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                            )
                    }
                }

            Button {
                viewModel.toggleExistingPhotoRemoval(photo)
            } label: {
                Image(systemName: "trash.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .red)
            }
            .buttonStyle(.plain)
            .padding(6)
        }
    }

    private func selectedPhotoThumbnail(_ image: UIImage) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Button {
                viewModel.removeSelectedPhoto()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.65))
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
