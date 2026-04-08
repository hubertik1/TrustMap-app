import PhotosUI
import SwiftUI

struct AddDishReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AddDishReviewViewModel
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isDeleteConfirmationPresented = false

    init(container: AppContainer, place: Place, existingReview: DishReview? = nil) {
        _viewModel = StateObject(
            wrappedValue: AddDishReviewViewModel(
                place: place,
                dishReviewRepository: container.dishReviewRepository,
                categoryRepository: container.categoryRepository,
                refreshCenter: container.refreshCenter,
                existingReview: existingReview
            )
        )
    }

    var body: some View {
        Form {
            Section("Place") {
                Text(viewModel.place.name)
                    .font(.headline)
                Text(viewModel.place.address)
                    .foregroundStyle(.secondary)
            }

            Section("Dish Review") {
                TextField("Dish name", text: $viewModel.dishName)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Rating")
                            .font(.subheadline.weight(.medium))

                        Spacer()

                        Text("\(viewModel.dishRating)/5")
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
                        Text("Loading categories...").tag(UUID?.none)
                    } else {
                        ForEach(viewModel.availableCategories) { category in
                            Text(category.name).tag(Optional(category.id))
                        }
                    }
                }

                Picker("Visibility", selection: $viewModel.visibility) {
                    ForEach(VisibilityStatus.allCases) { status in
                        Text(status.displayName).tag(status)
                    }
                }
            }

            Section("Photo") {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("Add Dish Photo", systemImage: "camera")
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
        .onChange(of: selectedPhotoItem) { _, item in
            Task {
                let data = try? await item?.loadTransferable(type: Data.self)
                viewModel.updateSelectedPhoto(with: data)
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

    private func existingPhotoThumbnail(_ photo: PhotoAsset) -> some View {
        ZStack(alignment: .topTrailing) {
            RemotePhotoView(asset: photo)
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
}

#Preview {
    let container = PreviewAppFactory.makeContainer()
    NavigationStack {
        AddDishReviewView(container: container, place: PreviewAppFactory.samplePlace(in: container))
    }
}
