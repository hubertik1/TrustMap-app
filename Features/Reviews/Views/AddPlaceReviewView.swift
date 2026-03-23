import PhotosUI
import SwiftUI

struct AddPlaceReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AddPlaceReviewViewModel
    @State private var selectedPhotoItems: [PhotosPickerItem] = []

    init(container: AppContainer, place: Place) {
        _viewModel = StateObject(
            wrappedValue: AddPlaceReviewViewModel(
                place: place,
                sessionStore: container.sessionStore,
                categoryRepository: container.categoryRepository,
                placeReviewRepository: container.placeReviewRepository
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

            Section("Review") {
                Stepper("Rating: \(viewModel.ratingOverall)/10", value: $viewModel.ratingOverall, in: 1...10)
                TextField("Description", text: $viewModel.descriptionText, axis: .vertical)
                    .lineLimit(3...6)

                Picker("Visibility", selection: $viewModel.visibility) {
                    ForEach(VisibilityStatus.allCases) { status in
                        Text(status.displayName).tag(status)
                    }
                }
            }

            Section("Category") {
                Picker("Existing Category", selection: $viewModel.selectedCategoryID) {
                    ForEach(viewModel.availableCategories, id: \.id) { category in
                        Text(category.name).tag(Optional(category.id))
                    }
                }

                TextField("Create new category", text: $viewModel.newCategoryName)
            }

            Section("Photos") {
                PhotosPicker(
                    selection: $selectedPhotoItems,
                    maxSelectionCount: 6,
                    matching: .images
                ) {
                    Label("Add Photos", systemImage: "photo.on.rectangle.angled")
                }

                if !viewModel.selectedPreviewImages.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(viewModel.selectedPreviewImages.enumerated()), id: \.offset) { _, image in
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 96, height: 96)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Add Place Review")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }

            ToolbarItem(placement: .confirmationAction) {
                if viewModel.isSaving {
                    ProgressView()
                } else {
                    Button("Save") {
                        Task { await viewModel.save() }
                    }
                }
            }
        }
        .task {
            await viewModel.loadCategories()
        }
        .onChange(of: selectedPhotoItems) { _, items in
            Task {
                var dataItems: [Data] = []

                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        dataItems.append(data)
                    }
                }

                viewModel.updateSelectedPhotos(with: dataItems)
            }
        }
        .onChange(of: viewModel.didSave) { _, didSave in
            if didSave {
                dismiss()
            }
        }
        .alert(
            "Unable to Save Review",
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
}

#Preview {
    let container = PreviewAppFactory.makeContainer()
    NavigationStack {
        AddPlaceReviewView(container: container, place: PreviewAppFactory.samplePlace(in: container))
    }
}
