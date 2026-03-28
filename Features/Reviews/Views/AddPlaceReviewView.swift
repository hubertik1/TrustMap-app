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
                sessionStore: container.sessionStore,
                categoryRepository: container.categoryRepository,
                placeReviewRepository: container.placeReviewRepository,
                existingReview: existingReview
            )
        )
    }

    var body: some View {
        Form {
            placeSection
            reviewSection
            categorySection
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
        Section {
            Text(viewModel.place.name)
                .font(.headline)
            Text(viewModel.place.address)
                .foregroundStyle(.secondary)
        }
    }

    private var reviewSection: some View {
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
    }

    private var categorySection: some View {
        Section("Category") {
            Picker("Category", selection: $viewModel.selectedCategoryID) {
                ForEach(viewModel.availableCategories, id: \.id) { category in
                    Text(category.name).tag(category.id as UUID?)
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
}

#Preview {
    let container = PreviewAppFactory.makeContainer()
    NavigationStack {
        AddPlaceReviewView(container: container, place: PreviewAppFactory.samplePlace(in: container))
    }
}
