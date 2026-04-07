import Foundation
import UniformTypeIdentifiers
import UIKit

@MainActor
final class PhotoRepository {
    private struct PreparedUpload {
        let data: Data
        let fileExtension: String
        let mimeType: String
    }

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func uploadPlaceReviewPhoto(reviewID: UUID, imageData: Data) async throws -> PhotoAsset {
        let preparedUpload = try prepareUpload(from: imageData)
        let multipart = MultipartFormData(
            fields: ["placeReviewId": reviewID.uuidString],
            file: .init(
                fieldName: "file",
                fileName: "place-review-\(reviewID.uuidString).\(preparedUpload.fileExtension)",
                mimeType: preparedUpload.mimeType,
                data: preparedUpload.data
            )
        )

        return try await apiClient.send(
            APIRequest<PhotoAsset>(
                method: .post,
                path: "photos/upload",
                body: .multipart(multipart),
                acceptedStatusCodes: [201]
            )
        )
    }

    func uploadDishReviewPhoto(reviewID: UUID, imageData: Data) async throws -> PhotoAsset {
        let preparedUpload = try prepareUpload(from: imageData)
        let multipart = MultipartFormData(
            fields: ["dishReviewId": reviewID.uuidString],
            file: .init(
                fieldName: "file",
                fileName: "dish-review-\(reviewID.uuidString).\(preparedUpload.fileExtension)",
                mimeType: preparedUpload.mimeType,
                data: preparedUpload.data
            )
        )

        return try await apiClient.send(
            APIRequest<PhotoAsset>(
                method: .post,
                path: "photos/upload",
                body: .multipart(multipart),
                acceptedStatusCodes: [201]
            )
        )
    }

    func deletePhoto(id: UUID) async throws {
        _ = try await apiClient.send(
            APIRequest<EmptyResponse>(
                method: .delete,
                path: "photos/\(id.uuidString)",
                acceptedStatusCodes: [204]
            )
        )
    }

    private func prepareUpload(from imageData: Data) throws -> PreparedUpload {
        guard let image = UIImage(data: imageData),
              let jpegData = image.jpegData(compressionQuality: 0.9) else {
            throw AppError.validationFailure("Select a supported image before uploading.")
        }

        return PreparedUpload(
            data: jpegData,
            fileExtension: "jpg",
            mimeType: UTType.jpeg.preferredMIMEType ?? "image/jpeg"
        )
    }
}
