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
    @State private var pendingSource: ReviewPhotoSource?
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isPreparingPhotos = false

    func body(content: Content) -> some View {
        content
            .popover(isPresented: $isSourceDialogPresented, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
                ReviewPhotoSourcePickerPopover(
                    showsCameraOption: showsCameraOption,
                    isPreparingPhotos: isPreparingPhotos,
                    onSourceSelected: selectSource
                )
                .presentationCompactAdaptation(.popover)
                .onDisappear(perform: presentPendingSource)
            }
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
                #if targetEnvironment(macCatalyst)
                EmptyView()
                #else
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
                #endif
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

    private var showsCameraOption: Bool {
        #if targetEnvironment(macCatalyst)
        return false
        #else
        return UIImagePickerController.isSourceTypeAvailable(.camera)
        #endif
    }

    private var allPhotosFailedMessage: String {
        allowsMultipleSelection
            ? "The selected photos couldn't be prepared."
            : "The selected photo couldn't be prepared."
    }

    private func selectSource(_ source: ReviewPhotoSource) {
        guard !isPreparingPhotos else {
            return
        }

        pendingSource = source
        isSourceDialogPresented = false
    }

    private func presentPendingSource() {
        guard !isPreparingPhotos, let pendingSource else {
            self.pendingSource = nil
            return
        }

        self.pendingSource = nil

        switch pendingSource {
        case .photoLibrary:
            selectedPhotoItems = []
            isPhotoLibraryPresented = true
        case .camera:
            isCameraPresented = true
        case .files:
            isFileImporterPresented = true
        }
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

private enum ReviewPhotoSource: Hashable {
    case photoLibrary
    case camera
    case files

    var title: String {
        switch self {
        case .photoLibrary:
            "Photo Library"
        case .camera:
            "Camera"
        case .files:
            "Files"
        }
    }

    var systemImage: String {
        switch self {
        case .photoLibrary:
            "photo.on.rectangle"
        case .camera:
            "camera"
        case .files:
            "folder"
        }
    }
}

private struct ReviewPhotoSourcePickerPopover: View {
    let showsCameraOption: Bool
    let isPreparingPhotos: Bool
    let onSourceSelected: (ReviewPhotoSource) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(sources.enumerated()), id: \.element) { index, source in
                sourceRow(source)

                if index < sources.count - 1 {
                    Divider()
                }
            }
        }
        .frame(width: 300)
    }

    private var sources: [ReviewPhotoSource] {
        if showsCameraOption {
            [.photoLibrary, .camera, .files]
        } else {
            [.photoLibrary, .files]
        }
    }

    private func sourceRow(_ source: ReviewPhotoSource) -> some View {
        Button {
            onSourceSelected(source)
        } label: {
            Label {
                Text(source.title)
                    .foregroundStyle(.primary)
            } icon: {
                Image(systemName: source.systemImage)
                    .foregroundStyle(.tint)
                    .frame(width: 24)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .frame(height: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isPreparingPhotos)
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

#if !targetEnvironment(macCatalyst)
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
#endif
