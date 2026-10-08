import Foundation
import ImageIO
import UIKit

@MainActor
final class RemoteImagePipeline {
    static let shared = RemoteImagePipeline()

    private let session: URLSession
    private let memoryCache = NSCache<NSString, UIImage>()
    private var inFlightRequests: [NSString: Task<UIImage, Error>] = [:]
    weak var sessionProvider: (any APISessionProviding)?

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
        let backendBaseURL = AppConfiguration.apiBaseURL
        let accessToken = sessionProvider?.currentAccessToken

        let task = Task(priority: .userInitiated) { [session] in
            try await Self.fetchImage(
                with: session,
                candidateURLs: candidateURLs,
                maxPixelSize: max(maxPixelSize, 1),
                backendBaseURL: backendBaseURL,
                accessToken: accessToken
            )
        }

        inFlightRequests[cacheKey] = task
        defer { inFlightRequests.removeValue(forKey: cacheKey) }

        let image: UIImage
        do {
            image = try await task.value
        } catch RemoteImagePipelineError.unauthorized {
            guard let sessionProvider else {
                throw AppError.invalidSession
            }

            do {
                let refreshedAccessToken = try await sessionProvider.refreshSession()
                image = try await Self.fetchImage(
                    with: session,
                    candidateURLs: candidateURLs,
                    maxPixelSize: max(maxPixelSize, 1),
                    backendBaseURL: backendBaseURL,
                    accessToken: refreshedAccessToken
                )
            } catch RemoteImagePipelineError.unauthorized {
                await sessionProvider.handleUnauthorizedSession()
                throw AppError.invalidSession
            }
        }

        memoryCache.setObject(image, forKey: cacheKey, cost: image.memoryCost)
        return image
    }

    func clearCache() {
        memoryCache.removeAllObjects()
        session.configuration.urlCache?.removeAllCachedResponses()
        inFlightRequests.values.forEach { $0.cancel() }
        inFlightRequests.removeAll()
    }

    private static func fetchImage(
        with session: URLSession,
        candidateURLs: [URL],
        maxPixelSize: Int,
        backendBaseURL: URL,
        accessToken: String?
    ) async throws -> UIImage {
        var lastError: Error?

        for url in candidateURLs {
            do {
                var request = URLRequest(url: url)
                request.cachePolicy = .useProtocolCachePolicy
                if let accessToken,
                   !accessToken.isEmpty,
                   isBackendURL(url, backendBaseURL: backendBaseURL) {
                    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                }

                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    lastError = AppError.underlying(L10n.thePhotoResponseWasInvalid)
                    continue
                }

                if httpResponse.statusCode == 401 {
                    throw RemoteImagePipelineError.unauthorized
                }

                guard (200..<300).contains(httpResponse.statusCode) else {
                    if httpResponse.statusCode == 404 {
                        continue
                    }

                    throw AppError.underlying(L10n.unableToLoadTheSelectedPhoto)
                }

                guard let image = downsampledImage(from: data, maxPixelSize: maxPixelSize) else {
                    lastError = AppError.underlying(L10n.thePhotoDataWasInvalid)
                    continue
                }

                return image
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
            }
        }

        throw lastError ?? AppError.underlying(L10n.unableToLoadTheSelectedPhoto)
    }

    private static func isBackendURL(_ url: URL, backendBaseURL: URL) -> Bool {
        guard let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let backendComponents = URLComponents(url: backendBaseURL, resolvingAgainstBaseURL: false) else {
            return false
        }

        return urlComponents.scheme?.lowercased() == backendComponents.scheme?.lowercased()
            && urlComponents.host?.lowercased() == backendComponents.host?.lowercased()
            && urlComponents.port == backendComponents.port
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

private enum RemoteImagePipelineError: Error {
    case unauthorized
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
