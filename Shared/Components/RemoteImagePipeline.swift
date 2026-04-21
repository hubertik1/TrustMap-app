import Foundation
import ImageIO
import UIKit

@MainActor
final class RemoteImagePipeline {
    static let shared = RemoteImagePipeline()

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
        candidateURLs: [URL],
        cacheKey: NSString,
        targetDisplaySize: CGSize,
        screenScale: CGFloat
    ) async throws -> UIImage {
        if let cached = memoryCache.object(forKey: cacheKey) {
            return cached
        }

        if let inFlightRequest = inFlightRequests[cacheKey] {
            return try await inFlightRequest.value
        }

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

extension UIImage {
    var memoryCost: Int {
        guard let cgImage else {
            let widthCost = Int(size.width * scale)
            let heightCost = Int(size.height * scale)
            return max(widthCost * heightCost * 4, 1)
        }

        return max(cgImage.bytesPerRow * cgImage.height, 1)
    }
}
