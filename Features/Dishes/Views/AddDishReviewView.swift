import PhotosUI
import SwiftUI

struct AddDishReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AddDishReviewViewModel
    @State private var selectedPhotoItem: PhotosPickerItem?

    init(container: AppContainer, place: Place) {
        _viewModel = StateObject(
            wrappedValue: AddDishReviewViewModel(
                place: place,
                sessionStore: container.sessionStore,
                placeReviewRepository: container.placeReviewRepository,
                dishReviewRepository: container.dishReviewRepository
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
                TextField("Dish category", text: $viewModel.dishCategory)
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
        }
        .navigationTitle("Add Dish Review")
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
        .alert(
            "Unable to Save Dish Review",
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
