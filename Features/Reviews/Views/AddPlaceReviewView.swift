import SwiftUI
import UIKit

struct AddPlaceReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AddPlaceReviewViewModel
    @State private var isPhotoSourceDialogPresented = false
    @State private var isDeleteConfirmationPresented = false
    private let showsCancelButton: Bool

    init(
        container: AppContainer,
        place: Place,
        existingReview: PlaceReview? = nil,
        showsCancelButton: Bool = true
    ) {
        self.showsCancelButton = showsCancelButton
        _viewModel = StateObject(
            wrappedValue: AddPlaceReviewViewModel(
                place: place,
                currentUserID: container.sessionStore.currentUser?.id,
                placeRepository: container.placeRepository,
                placeReviewRepository: container.placeReviewRepository,
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
            isPresented: isShowingError
        ) {
            Button(L10n.ok, role: .cancel) {}
        } message: {
            Text(errorAlertMessage)
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
            placeSection
            reviewSection
            photosSection
            deleteSection
        }
        .scrollDismissesKeyboard(.interactively)
        .trustMapDismissKeyboardOnTap()
    }

    private var isShowingError: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private var errorAlertMessage: String {
        viewModel.errorMessage ?? ""
    }

    private var visibleExistingPhotos: [PhotoAsset] {
        viewModel.existingPhotos.filter { photo in
            !viewModel.isExistingPhotoMarkedForRemoval(photo)
        }
    }

    private var placeSection: some View {
        Section(L10n.place) {
            if viewModel.canEditCustomPlaceDisplayName {
                TextField(L10n.placeName, text: $viewModel.customPlaceDisplayName)
                    .font(.headline)
                    .textInputAutocapitalization(.words)
            } else {
                Text(viewModel.place.displayName)
                    .font(.headline)
            }

            if let addressLine = viewModel.placeAddressLine {
                Text(addressLine)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var reviewSection: some View {
        Section(L10n.review) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(L10n.rating)
                        .font(.subheadline.weight(.medium))

                    Spacer()

                    Text("\(RatingDisplayFormatter.rating(viewModel.ratingOverall))/5")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                StarRatingInputView(rating: $viewModel.ratingOverall)
            }

            TextField(L10n.descriptionOptional, text: $viewModel.descriptionText, axis: .vertical)
                .lineLimit(3...6)

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
                Text(L10n.chooseAnActiveCategoryBeforeSaving)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var photosSection: some View {
        Section(L10n.photos) {
            Button {
                isPhotoSourceDialogPresented = true
            } label: {
                Label(L10n.addPhotos, systemImage: "photo.on.rectangle.angled")
            }
            .accessibilityLabel(L10n.addPhotos)
            .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
            .reviewPhotoSourcePicker(
                isPresented: $isPhotoSourceDialogPresented,
                title: L10n.addPhotos,
                allowsMultipleSelection: true
            ) { preparedPhotos, didSkipAnyPhotos in
                viewModel.appendSelectedPhotos(preparedPhotos, didSkipAnyPhotos: didSkipAnyPhotos)
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

            if !viewModel.selectedPreviewImages.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.newPhotos)
                        .font(.subheadline.weight(.medium))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(viewModel.selectedPreviewImages.enumerated()), id: \.offset) { index, image in
                                selectedPhotoThumbnail(image, index: index)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var deleteSection: some View {
        if viewModel.isEditing {
            Section {
                Button(role: .destructive) {
                    isDeleteConfirmationPresented = true
                } label: {
                    Text(L10n.deleteReview)
                }
                .disabled(viewModel.isSaving || viewModel.isDeleting)
                .confirmationDialog(
                    L10n.deleteThisReview,
                    isPresented: $isDeleteConfirmationPresented,
                    titleVisibility: .visible
                ) {
                    Button(L10n.deleteReview, role: .destructive) {
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

    private func existingPhotoThumbnail(_ photo: PhotoAsset) -> some View {
        ZStack(alignment: .topTrailing) {
            RemotePhotoView(
                asset: photo,
                preferredVariant: .thumbnail,
                targetDisplaySize: CGSize(width: 96, height: 96)
            )
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

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

    private func selectedPhotoThumbnail(_ image: UIImage, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Button {
                viewModel.removeSelectedPhoto(at: index)
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
        AddPlaceReviewView(container: container, place: PreviewAppFactory.samplePlace(in: container))
    }
}
