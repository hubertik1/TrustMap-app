import Foundation
import SwiftUI
import UIKit

struct RemotePhotoView: View {
    let asset: PhotoAsset
    var preferredVariant: PhotoAssetVariant = .thumbnail
    var placeholderSystemImage = "photo"
    var contentMode: ContentMode = .fill
    var targetDisplaySize = CGSize(width: 96, height: 96)

    @State private var loadedImage: UIImage?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let loadedImage {
                configuredImage(Image(uiImage: loadedImage).resizable())
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.secondarySystemBackground))
            } else {
                photoPlaceholder
            }
        }
        .task(id: requestCacheKey) {
            await loadImage()
        }
    }

    private var requestCacheKey: String {
        let urls = asset.resolvedURLs(for: preferredVariant)
            .map(\.absoluteString)
            .joined(separator: "|")
        let width = Int(max(1, targetDisplaySize.width.rounded(.up)))
        let height = Int(max(1, targetDisplaySize.height.rounded(.up)))
        return "\(preferredVariant.rawValue)|\(width)x\(height)|\(urls)"
    }

    @ViewBuilder
    private func configuredImage(_ image: Image) -> some View {
        switch contentMode {
        case .fill:
            image
                .scaledToFill()
        case .fit:
            image
                .scaledToFit()
        }
    }

    private var photoPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(.secondarySystemBackground))
            .overlay(Image(systemName: placeholderSystemImage).foregroundStyle(.secondary))
    }

    @MainActor
    private func loadImage() async {
        let screenScale = UIScreen.main.scale
        let normalizedSize = CGSize(
            width: max(targetDisplaySize.width, 1),
            height: max(targetDisplaySize.height, 1)
        )

        guard !asset.resolvedURLs(for: preferredVariant).isEmpty else {
            loadedImage = nil
            isLoading = false
            return
        }

        isLoading = true

        do {
            loadedImage = try await RemoteImagePipeline.shared.loadImage(
                candidateURLs: asset.resolvedURLs(for: preferredVariant),
                cacheKey: requestCacheKey as NSString,
                targetDisplaySize: normalizedSize,
                screenScale: screenScale
            )
        } catch is CancellationError {
            return
        } catch {
            loadedImage = nil
        }

        isLoading = false
    }
}
