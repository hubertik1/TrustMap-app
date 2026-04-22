import PhotosUI
import SwiftUI

struct AddPlaceReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AddPlaceReviewViewModel
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isDeleteConfirmationPresented = false

    init(container: AppContainer, place: Place, existingReview: PlaceReview? = nil) {
        _viewModel = StateObject(
            wrappedValue: AddPlaceReviewViewModel(
                place: place,
                currentUserID: container.sessionStore.currentUser?.id,
                placeRepository: container.placeRepository,
                placeReviewRepository: container.placeReviewRepository,
                categoryRepository: container.categoryRepository,
                refreshCenter: container.refreshCenter,
                preferencesStore: container.preferencesStore,
                existingReview: existingReview
            )
        )
    }

    var body: some View {
        Form {
            placeSection
            reviewSection
            photosSection
            deleteSection
        }
        .navigationTitle(viewModel.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }

            ToolbarItem(placement: .confirmationAction) {
                if viewModel.isSaving || viewModel.isDeleting {
                    ProgressView()
                } else {
                    Button("Save") {
                        Task { await viewModel.save() }
                    }
                }
            }
        }
        .task {
            await viewModel.load()
        }
        .onChange(of: selectedPhotoItems) { _, items in
            guard !items.isEmpty else {
                return
            }

            Task {
                selectedPhotoItems = []
                await prepareSelectedPhotos(from: items)
            }
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
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorAlertMessage)
        }
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

    private var placeSection: some View {
        Section("Place") {
            if viewModel.canEditCustomPlaceDisplayName {
                TextField("Place name", text: $viewModel.customPlaceDisplayName)
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
        Section("Review") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Rating")
                        .font(.subheadline.weight(.medium))

                    Spacer()

                    Text("\(viewModel.ratingOverall)/5")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                StarRatingInputView(rating: $viewModel.ratingOverall)
            }

            TextField("Description (optional)", text: $viewModel.descriptionText, axis: .vertical)
                .lineLimit(3...6)

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
                Text("Choose an active category before saving.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Picker("Visibility", selection: $viewModel.visibility) {
                ForEach(VisibilityStatus.allCases) { status in
                    Text(status.displayName).tag(status)
                }
            }
        }
    }

    private var photosSection: some View {
        Section("Photos") {
            PhotosPicker(
                selection: $selectedPhotoItems,
                maxSelectionCount: 6,
                matching: .images
            ) {
                Label("Add Photos", systemImage: "photo.on.rectangle.angled")
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

            if !viewModel.selectedPreviewImages.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("New Photos")
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
                    Text("Delete Review")
                }
                .disabled(viewModel.isSaving || viewModel.isDeleting)
                .confirmationDialog(
                    "Delete this review?",
                    isPresented: $isDeleteConfirmationPresented,
                    titleVisibility: .visible
                ) {
                    Button("Delete Review", role: .destructive) {
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

    @MainActor
    private func prepareSelectedPhotos(from items: [PhotosPickerItem]) async {
        guard !items.isEmpty else {
            return
        }

        var preparedPhotos: [SelectedPhotoUpload] = []
        var didSkipAnyPhotos = false

        for item in items {
            if Task.isCancelled {
                return
            }

            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    didSkipAnyPhotos = true
                    continue
                }

                preparedPhotos.append(try await PhotoUploadPreparation.prepareSelectedPhoto(from: data))
            } catch is CancellationError {
                return
            } catch {
                didSkipAnyPhotos = true
            }
        }

        viewModel.appendSelectedPhotos(preparedPhotos, didSkipAnyPhotos: didSkipAnyPhotos)
    }
}

#Preview {
    let container = PreviewAppFactory.makeContainer()
    NavigationStack {
        AddPlaceReviewView(container: container, place: PreviewAppFactory.samplePlace(in: container))
    }
}
