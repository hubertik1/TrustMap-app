import CoreGraphics
import ImageIO
import UIKit
import UniformTypeIdentifiers

struct SelectedPhotoUpload: Identifiable {
    let id: UUID
    let uploadData: Data
    let previewImage: UIImage

    init(id: UUID = UUID(), uploadData: Data, previewImage: UIImage) {
        self.id = id
        self.uploadData = uploadData
        self.previewImage = previewImage
    }
}

enum PhotoUploadPreparation {
    private struct PreparedPayload: Sendable {
        let uploadData: Data
        let previewData: Data
    }

    private static let uploadMaxPixelSize = 2_560
    private static let previewMaxPixelSize = 512
    private static let uploadCompressionQuality: CGFloat = 0.82
    private static let previewCompressionQuality: CGFloat = 0.72

    @MainActor
    static func prepareSelectedPhoto(from rawData: Data) async throws -> SelectedPhotoUpload {
        let payload = try await Task.detached(priority: .userInitiated) {
            try preparePayload(from: rawData)
        }.value

        guard let previewImage = UIImage(data: payload.previewData) else {
            throw AppError.validationFailure(L10n.selectASupportedImageBeforeUploading)
        }

        return SelectedPhotoUpload(
            uploadData: payload.uploadData,
            previewImage: previewImage
        )
    }

    private static func preparePayload(from rawData: Data) throws -> PreparedPayload {
        guard let source = CGImageSourceCreateWithData(rawData as CFData, nil) else {
            throw AppError.validationFailure(L10n.selectASupportedImageBeforeUploading)
        }

        guard let uploadImage = downsampledImage(from: source, maxPixelSize: uploadMaxPixelSize) else {
            throw AppError.validationFailure(L10n.selectASupportedImageBeforeUploading)
        }

        let previewImage = downsampledImage(from: source, maxPixelSize: previewMaxPixelSize) ?? uploadImage

        return PreparedPayload(
            uploadData: try jpegData(from: uploadImage, compressionQuality: uploadCompressionQuality),
            previewData: try jpegData(from: previewImage, compressionQuality: previewCompressionQuality)
        )
    }

    private static func downsampledImage(from source: CGImageSource, maxPixelSize: Int) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCache: false,
            kCGImageSourceShouldCacheImmediately: false,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]

        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private static func jpegData(from image: CGImage, compressionQuality: CGFloat) throws -> Data {
        let flattenedImage = opaqueImage(from: image) ?? image
        let mutableData = NSMutableData()

        guard let destination = CGImageDestinationCreateWithData(
            mutableData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw AppError.validationFailure(L10n.selectASupportedImageBeforeUploading)
        }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: compressionQuality
        ]

        CGImageDestinationAddImage(destination, flattenedImage, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw AppError.validationFailure(L10n.selectASupportedImageBeforeUploading)
        }

        return mutableData as Data
    }

    private static func opaqueImage(from image: CGImage) -> CGImage? {
        let alphaInfo = image.alphaInfo
        let hasAlpha = alphaInfo == .first
            || alphaInfo == .last
            || alphaInfo == .premultipliedFirst
            || alphaInfo == .premultipliedLast
            || alphaInfo == .alphaOnly

        guard hasAlpha else {
            return nil
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            return nil
        }

        context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return context.makeImage()
    }
}
