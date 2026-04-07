import SwiftUI

private struct PhotoGridSelectedPhoto: Identifiable {
    let asset: PhotoAsset
    var id: UUID { asset.id }
}

struct PhotoGridView: View {
    let assets: [PhotoAsset]
    var allowsFullscreenPresentation = false

    @State private var selectedPhoto: PhotoGridSelectedPhoto?

    var body: some View {
        if !assets.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(assets) { asset in
                        photoThumbnail(for: asset)
                    }
                }
                .padding(.vertical, 4)
            }
            .fullScreenCover(item: $selectedPhoto) { selectedPhoto in
                PhotoLightboxView(
                    photos: assets,
                    initialPhotoID: selectedPhoto.id
                )
            }
        }
    }

    @ViewBuilder
    private func photoThumbnail(for asset: PhotoAsset) -> some View {
        if allowsFullscreenPresentation {
            Button {
                selectedPhoto = PhotoGridSelectedPhoto(asset: asset)
            } label: {
                RemotePhotoView(asset: asset)
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        } else {
            RemotePhotoView(asset: asset)
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

private struct PhotoLightboxView: View {
    @Environment(\.dismiss) private var dismiss

    let photos: [PhotoAsset]
    @State private var selectedPhotoID: UUID

    init(photos: [PhotoAsset], initialPhotoID: UUID) {
        self.photos = photos
        _selectedPhotoID = State(initialValue: initialPhotoID)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            TabView(selection: $selectedPhotoID) {
                ForEach(photos) { photo in
                    RemotePhotoView(asset: photo)
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                        .background(Color.black)
                        .tag(photo.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .automatic : .never))

            Button("Done") {
                dismiss()
            }
            .padding(.top, 16)
            .padding(.trailing, 16)
            .foregroundStyle(.white)
        }
    }
}

struct RemotePhotoView: View {
    let asset: PhotoAsset
    var placeholderSystemImage = "photo"

    var body: some View {
        if let resolvedURL = asset.resolvedURL {
            AsyncImage(url: resolvedURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.secondarySystemBackground))
                case .failure:
                    photoPlaceholder
                @unknown default:
                    photoPlaceholder
                }
            }
        } else {
            photoPlaceholder
        }
    }

    private var photoPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(.secondarySystemBackground))
            .overlay(Image(systemName: placeholderSystemImage).foregroundStyle(.secondary))
    }
}
