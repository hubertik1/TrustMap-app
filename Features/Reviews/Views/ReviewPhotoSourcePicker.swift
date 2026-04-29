import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct ReviewPhotoSourcePicker: ViewModifier {
    @Binding var isSourceDialogPresented: Bool

    let title: String
    let allowsMultipleSelection: Bool
    let onPhotosPrepared: ([SelectedPhotoUpload], Bool) -> Void
    let onError: (Error) -> Void

    @State private var isPhotoLibraryPresented = false
    @State private var isCameraPresented = false
    @State private var isFileImporterPresented = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isPreparingPhotos = false

    func body(content: Content) -> some View {
        content
            .confirmationDialog(title, isPresented: $isSourceDialogPresented) {
                Button("Photo Library") {
                    guard !isPreparingPhotos else {
                        return
                    }

                    selectedPhotoItems = []
                    isPhotoLibraryPresented = true
                }
                .disabled(isPreparingPhotos)

                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Camera") {
                        guard !isPreparingPhotos else {
                            return
                        }

                        isCameraPresented = true
                    }
                    .disabled(isPreparingPhotos)
                }

                Button("Files") {
                    guard !isPreparingPhotos else {
                        return
                    }

                    isFileImporterPresented = true
                }
                .disabled(isPreparingPhotos)
            }
            .presentationBackground(Color(uiColor: .systemGroupedBackground))
            .photosPicker(
                isPresented: $isPhotoLibraryPresented,
                selection: $selectedPhotoItems,
                maxSelectionCount: photoLibrarySelectionLimit,
                matching: .images
            )
            .onChange(of: selectedPhotoItems) { _, items in
                guard !items.isEmpty else {
                    return
                }

                selectedPhotoItems = []
                Task {
                    await preparePhotoPickerItems(items)
                }
            }
            .sheet(isPresented: $isCameraPresented) {
                ReviewCameraPicker {
                    isCameraPresented = false
                } onImagePicked: { data in
                    isCameraPresented = false
                    Task {
                        await prepareDataItems([data], didSkipAnyPhotos: false)
                    }
                } onFailure: {
                    isCameraPresented = false
                    onError(AppError.validationFailure("The captured photo couldn't be prepared."))
                }
            }
            .fileImporter(
                isPresented: $isFileImporterPresented,
                allowedContentTypes: [.image],
                allowsMultipleSelection: allowsMultipleSelection,
                onCompletion: handleFileImport
            )
    }

    private var photoLibrarySelectionLimit: Int? {
        allowsMultipleSelection ? nil : 1
    }

    private var allPhotosFailedMessage: String {
        allowsMultipleSelection
            ? "The selected photos couldn't be prepared."
            : "The selected photo couldn't be prepared."
    }

    @MainActor
    private func preparePhotoPickerItems(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty, !isPreparingPhotos else {
            return
        }

        isPreparingPhotos = true
        defer { isPreparingPhotos = false }

        var dataItems: [Data] = []
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

                dataItems.append(data)
            } catch is CancellationError {
                return
            } catch {
                didSkipAnyPhotos = true
            }
        }

        await finishPreparingDataItems(dataItems, didSkipAnyPhotos: didSkipAnyPhotos)
    }

    @MainActor
    private func prepareDataItems(_ dataItems: [Data], didSkipAnyPhotos: Bool) async {
        guard !isPreparingPhotos else {
            return
        }

        isPreparingPhotos = true
        defer { isPreparingPhotos = false }

        await finishPreparingDataItems(dataItems, didSkipAnyPhotos: didSkipAnyPhotos)
    }

    @MainActor
    private func prepareFileURLs(_ urls: [URL]) async {
        guard !urls.isEmpty, !isPreparingPhotos else {
            return
        }

        isPreparingPhotos = true
        defer { isPreparingPhotos = false }

        let loadedFiles = await loadFileData(from: urls)
        await finishPreparingDataItems(
            loadedFiles.dataItems,
            didSkipAnyPhotos: loadedFiles.didSkipAnyPhotos
        )
    }

    @MainActor
    private func finishPreparingDataItems(_ dataItems: [Data], didSkipAnyPhotos: Bool) async {
        guard !dataItems.isEmpty || didSkipAnyPhotos else {
            return
        }

        var preparedPhotos: [SelectedPhotoUpload] = []
        var didSkipAnyPhotos = didSkipAnyPhotos

        for data in dataItems {
            if Task.isCancelled {
                return
            }

            do {
                preparedPhotos.append(try await PhotoUploadPreparation.prepareSelectedPhoto(from: data))
            } catch is CancellationError {
                return
            } catch {
                didSkipAnyPhotos = true
            }
        }

        if preparedPhotos.isEmpty {
            if didSkipAnyPhotos {
                onError(AppError.validationFailure(allPhotosFailedMessage))
            }
            return
        }

        onPhotosPrepared(preparedPhotos, didSkipAnyPhotos)
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard !urls.isEmpty, !isPreparingPhotos else {
                return
            }

            Task {
                await prepareFileURLs(urls)
            }
        case .failure(let error):
            guard !isUserCancellation(error) else {
                return
            }

            onError(error)
        }
    }

    private func loadFileData(from urls: [URL]) async -> (dataItems: [Data], didSkipAnyPhotos: Bool) {
        await Task.detached(priority: .userInitiated) {
            var dataItems: [Data] = []
            var didSkipAnyPhotos = false

            for url in urls {
                if Task.isCancelled {
                    return (dataItems, didSkipAnyPhotos)
                }

                let didStart = url.startAccessingSecurityScopedResource()
                defer {
                    if didStart {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                do {
                    dataItems.append(try Data(contentsOf: url))
                } catch {
                    didSkipAnyPhotos = true
                }
            }

            return (dataItems, didSkipAnyPhotos)
        }.value
    }

    private func isUserCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        let nsError = error as NSError
        return nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError
    }
}

extension View {
    func reviewPhotoSourcePicker(
        isPresented: Binding<Bool>,
        title: String,
        allowsMultipleSelection: Bool,
        onPhotosPrepared: @escaping ([SelectedPhotoUpload], Bool) -> Void,
        onError: @escaping (Error) -> Void
    ) -> some View {
        modifier(
            ReviewPhotoSourcePicker(
                isSourceDialogPresented: isPresented,
                title: title,
                allowsMultipleSelection: allowsMultipleSelection,
                onPhotosPrepared: onPhotosPrepared,
                onError: onError
            )
        )
    }
}

private struct ReviewCameraPicker: UIViewControllerRepresentable {
    let onCancel: () -> Void
    let onImagePicked: (Data) -> Void
    let onFailure: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = [UTType.image.identifier]
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: ReviewCameraPicker

        init(parent: ReviewCameraPicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard let image = info[.originalImage] as? UIImage,
                  let data = image.jpegData(compressionQuality: 0.9) else {
                parent.onFailure()
                return
            }

            parent.onImagePicked(data)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel()
        }
    }
}
