import PhotosUI
import SwiftUI

struct AddDishReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AddDishReviewViewModel
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isDeleteConfirmationPresented = false

    init(container: AppContainer, place: Place, existingReview: DishReview? = nil, existingPhotoData: Data? = nil) {
        _viewModel = StateObject(
            wrappedValue: AddDishReviewViewModel(
                place: place,
                sessionStore: container.sessionStore,
                placeReviewRepository: container.placeReviewRepository,
                dishReviewRepository: container.dishReviewRepository,
                existingReview: existingReview,
                existingPhotoData: existingPhotoData
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
                Stepper("Rating: \(viewModel.dishRating)/10", value: $viewModel.dishRating, in: 1...10)
                TextField("Short review", text: $viewModel.dishReviewText, axis: .vertical)
                    .lineLimit(3...5)
                TextField("Price", text: $viewModel.priceText)
                    .keyboardType(.decimalPad)
            }

            Section("Photo") {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("Add Dish Photo", systemImage: "camera")
                }

                if let image = viewModel.selectedPreviewImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
}

#Preview {
    let container = PreviewAppFactory.makeContainer()
    NavigationStack {
        AddDishReviewView(container: container, place: PreviewAppFactory.samplePlace(in: container))
    }
}
