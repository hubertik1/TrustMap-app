import SwiftUI
import UIKit

private struct PhotoGridSelectedPhoto: Identifiable {
    let asset: PhotoAsset
    var id: UUID { asset.id }
}

struct PhotoGridView: View {
    let assets: [PhotoAsset]
    var presentationAssets: [PhotoAsset]?
    var allowsFullscreenPresentation = false
    var thumbnailSize = CGSize(width: 96, height: 96)
    var cornerRadius: CGFloat = 12
    var spacing: CGFloat = 12

    @State private var selectedPhoto: PhotoGridSelectedPhoto?

    var body: some View {
        if !assets.isEmpty {
            #if targetEnvironment(macCatalyst)
            photoStrip
                .sheet(item: $selectedPhoto) { selectedPhoto in
                    PhotoLightboxView(
                        photos: lightboxAssets,
                        initialPhotoID: selectedPhoto.id
                    )
                    .trustMapMacSheet(width: 860, minHeight: 640)
                }
            #else
            photoStrip
                .fullScreenCover(item: $selectedPhoto) { selectedPhoto in
                    PhotoLightboxView(
                        photos: lightboxAssets,
                        initialPhotoID: selectedPhoto.id
                    )
                }
            #endif
        }
    }

    private var photoStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: spacing) {
                ForEach(assets.indices, id: \.self) { index in
                    photoThumbnail(for: assets[index], at: index)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var lightboxAssets: [PhotoAsset] {
        guard let presentationAssets, !presentationAssets.isEmpty else {
            return assets
        }

        return presentationAssets
    }

    @ViewBuilder
    private func photoThumbnail(for asset: PhotoAsset, at index: Int) -> some View {
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
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel(forPhotoAt: index))
        } else {
            RemotePhotoView(
                asset: asset,
                preferredVariant: .thumbnail,
                targetDisplaySize: thumbnailSize
            )
                .frame(width: thumbnailSize.width, height: thumbnailSize.height)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityLabel(forPhotoAt: index))
        }
    }

    private func accessibilityLabel(forPhotoAt index: Int) -> String {
        guard assets.count > 1 else {
            return L10n.reviewPhoto
        }

        return L10n.reviewPhotoValueOfValue(String(describing: index + 1), String(describing: assets.count))
    }
}

private struct PhotoLightboxView: View {
    @Environment(\.dismiss) private var dismiss

    let photos: [PhotoAsset]
    @State private var selectedPhotoID: UUID

    init(photos: [PhotoAsset], initialPhotoID: UUID) {
        self.photos = photos

        let resolvedInitialID = photos.contains(where: { $0.id == initialPhotoID })
            ? initialPhotoID
            : photos.first?.id ?? initialPhotoID
        _selectedPhotoID = State(initialValue: resolvedInitialID)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            if !photos.isEmpty {
                GeometryReader { proxy in
                    TabView(selection: $selectedPhotoID) {
                        ForEach(photos) { photo in
                            RemotePhotoView(
                                asset: photo,
                                preferredVariant: .medium,
                                contentMode: .fit,
                                targetDisplaySize: proxy.size
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.horizontal, 16)
                            .padding(.top, 56)
                            .padding(.bottom, photos.count > 1 ? 44 : 16)
                            .background(Color.black)
                            .tag(photo.id)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .automatic : .never))
                }
            }

            topBar
        }
    }

    private var selectedIndex: Int {
        photos.firstIndex(where: { $0.id == selectedPhotoID }) ?? 0
    }

    private var topBar: some View {
        ZStack {
            if photos.count > 1 {
                Text(L10n.valueOfValue(String(describing: selectedIndex + 1), String(describing: photos.count)))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .monospacedDigit()
                    .accessibilityLabel(L10n.photoValueOfValue(String(describing: selectedIndex + 1), String(describing: photos.count)))
            }

            HStack {
                Spacer()

                Button(L10n.done) {
                    dismiss()
                }
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.done)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 22)
        .background {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.72),
                    Color.black.opacity(0.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        }
    }
}
