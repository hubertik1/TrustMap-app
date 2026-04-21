import SwiftUI
import UIKit

private struct PhotoGridSelectedPhoto: Identifiable {
    let asset: PhotoAsset
    var id: UUID { asset.id }
}

struct PhotoGridView: View {
    let assets: [PhotoAsset]
    var allowsFullscreenPresentation = false
    var thumbnailSize = CGSize(width: 96, height: 96)
    var cornerRadius: CGFloat = 12
    var spacing: CGFloat = 12

    @State private var selectedPhoto: PhotoGridSelectedPhoto?

    var body: some View {
        if !assets.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing) {
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
                RemotePhotoView(
                    asset: asset,
                    preferredVariant: .thumbnail,
                    targetDisplaySize: thumbnailSize
                )
                    .frame(width: thumbnailSize.width, height: thumbnailSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
            .buttonStyle(.plain)
        } else {
            RemotePhotoView(
                asset: asset,
                preferredVariant: .thumbnail,
                targetDisplaySize: thumbnailSize
            )
                .frame(width: thumbnailSize.width, height: thumbnailSize.height)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
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
                    RemotePhotoView(
                        asset: photo,
                        preferredVariant: .medium,
                        contentMode: .fit,
                        targetDisplaySize: UIScreen.main.bounds.size
                    )
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
