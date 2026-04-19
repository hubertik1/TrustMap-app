import Foundation
import ImageIO
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
            loadedImage = try await PhotoImagePipeline.shared.loadImage(
                for: asset,
                preferredVariant: preferredVariant,
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

@MainActor
private final class PhotoImagePipeline {
    static let shared = PhotoImagePipeline()

    private let session: URLSession
    private let memoryCache = NSCache<NSString, UIImage>()
    private var inFlightRequests: [NSString: Task<UIImage, Error>] = [:]

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .useProtocolCachePolicy
        configuration.timeoutIntervalForRequest = AppConfiguration.networkTimeout
        configuration.timeoutIntervalForResource = AppConfiguration.networkTimeout
        configuration.urlCache = URLCache(
            memoryCapacity: 64 * 1_024 * 1_024,
            diskCapacity: 512 * 1_024 * 1_024
        )

        session = URLSession(configuration: configuration)
        memoryCache.totalCostLimit = 96 * 1_024 * 1_024
    }

    func loadImage(
        for asset: PhotoAsset,
        preferredVariant: PhotoAssetVariant,
        targetDisplaySize: CGSize,
        screenScale: CGFloat
    ) async throws -> UIImage {
        let cacheKey = makeCacheKey(
            asset: asset,
            preferredVariant: preferredVariant,
            targetDisplaySize: targetDisplaySize,
            screenScale: screenScale
        )

        if let cached = memoryCache.object(forKey: cacheKey) {
            return cached
        }

        if let inFlightRequest = inFlightRequests[cacheKey] {
            return try await inFlightRequest.value
        }

        let candidateURLs = asset.resolvedURLs(for: preferredVariant)
        let maxPixelSize = max(
            Int((targetDisplaySize.width * screenScale).rounded(.up)),
            Int((targetDisplaySize.height * screenScale).rounded(.up))
        )

        let task = Task(priority: .userInitiated) { [session] in
            try await Self.fetchImage(
                with: session,
                candidateURLs: candidateURLs,
                maxPixelSize: max(maxPixelSize, 1)
            )
        }

        inFlightRequests[cacheKey] = task
        defer { inFlightRequests.removeValue(forKey: cacheKey) }

        let image = try await task.value
        memoryCache.setObject(image, forKey: cacheKey, cost: image.memoryCost)
        return image
    }

    private func makeCacheKey(
        asset: PhotoAsset,
        preferredVariant: PhotoAssetVariant,
        targetDisplaySize: CGSize,
        screenScale: CGFloat
    ) -> NSString {
        let urls = asset.resolvedURLs(for: preferredVariant)
            .map(\.absoluteString)
            .joined(separator: "|")
        let width = Int((targetDisplaySize.width * screenScale).rounded(.up))
        let height = Int((targetDisplaySize.height * screenScale).rounded(.up))
        return "\(preferredVariant.rawValue)|\(width)x\(height)|\(urls)" as NSString
    }

    private static func fetchImage(
        with session: URLSession,
        candidateURLs: [URL],
        maxPixelSize: Int
    ) async throws -> UIImage {
        var lastError: Error?

        for url in candidateURLs {
            do {
                var request = URLRequest(url: url)
                request.cachePolicy = .useProtocolCachePolicy

                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    lastError = AppError.underlying("The photo response was invalid.")
                    continue
                }

                guard (200..<300).contains(httpResponse.statusCode) else {
                    if httpResponse.statusCode == 404 {
                        continue
                    }

                    throw AppError.underlying("Unable to load the selected photo.")
                }

                guard let image = downsampledImage(from: data, maxPixelSize: maxPixelSize) else {
                    lastError = AppError.underlying("The photo data was invalid.")
                    continue
                }

                return image
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
            }
        }

        throw lastError ?? AppError.underlying("Unable to load the selected photo.")
    }

    private static func downsampledImage(from data: Data, maxPixelSize: Int) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCache: false,
            kCGImageSourceShouldCacheImmediately: false,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]

        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        return UIImage(cgImage: image)
    }
}

private extension UIImage {
    var memoryCost: Int {
        guard let cgImage else {
            let widthCost = Int(size.width * scale)
            let heightCost = Int(size.height * scale)
            return max(widthCost * heightCost * 4, 1)
        }

        return max(cgImage.bytesPerRow * cgImage.height, 1)
    }
}
