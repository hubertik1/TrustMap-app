import SwiftUI

private struct PhotoGridDisplayPhoto: Identifiable {
    let id: UUID
    let image: UIImage
}

private struct PhotoGridSelectedPhoto: Identifiable {
    let id: UUID
}

struct PhotoGridView: View {
    let assets: [PhotoAsset]
    let imageDataProvider: (PhotoAsset) -> Data?
    var allowsFullscreenPresentation = false

    @State private var selectedPhoto: PhotoGridSelectedPhoto?

    var body: some View {
        let photos = displayPhotos

        if !photos.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(photos) { photo in
                        photoThumbnail(for: photo)
                    }
                }
                .padding(.vertical, 4)
            }
            .fullScreenCover(item: $selectedPhoto) { selectedPhoto in
                PhotoLightboxView(
                    photos: photos,
                    initialPhotoID: selectedPhoto.id
                )
            }
        }
    }

    private var displayPhotos: [PhotoGridDisplayPhoto] {
        assets.compactMap { asset in
            guard let data = imageDataProvider(asset),
                  let image = UIImage(data: data) else {
                return nil
            }

            return PhotoGridDisplayPhoto(id: asset.id, image: image)
        }
    }

    @ViewBuilder
    private func photoThumbnail(for photo: PhotoGridDisplayPhoto) -> some View {
        if allowsFullscreenPresentation {
            Button {
                selectedPhoto = PhotoGridSelectedPhoto(id: photo.id)
            } label: {
                photoImage(for: photo)
            }
            .buttonStyle(.plain)
        } else {
            photoImage(for: photo)
        }
    }

    private func photoImage(for photo: PhotoGridDisplayPhoto) -> some View {
        Image(uiImage: photo.image)
            .resizable()
            .scaledToFill()
            .frame(width: 96, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct PhotoLightboxView: View {
    @Environment(\.dismiss) private var dismiss

    let photos: [PhotoGridDisplayPhoto]

    @State private var selectedPhotoID: UUID

    init(photos: [PhotoGridDisplayPhoto], initialPhotoID: UUID) {
        self.photos = photos
        _selectedPhotoID = State(initialValue: initialPhotoID)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            TabView(selection: $selectedPhotoID) {
                ForEach(photos) { photo in
                    Image(uiImage: photo.image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                        .tag(photo.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .automatic : .never))
            .background(Color.black)

            Button("Done") {
                dismiss()
            }
            .padding(.top, 16)
            .padding(.trailing, 16)
            .foregroundStyle(.white)
        }
    }
}
