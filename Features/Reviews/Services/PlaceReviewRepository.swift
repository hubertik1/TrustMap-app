import Foundation

@MainActor
final class PlaceReviewRepository {
    private struct CreatePlaceReviewPayload: Encodable {
        let placeId: UUID
        let visibility: VisibilityStatus
        let rating: Int
        let title: String?
        let body: String?
    }

    private struct UpdatePlaceReviewPayload: Encodable {
        let visibility: VisibilityStatus
        let rating: Int
        let title: String?
        let body: String?
    }

    private let apiClient: APIClient
    private let photoRepository: PhotoRepository

    init(apiClient: APIClient, photoRepository: PhotoRepository) {
        self.apiClient = apiClient
        self.photoRepository = photoRepository
    }

    func fetchReviews(
        placeID: UUID? = nil,
        authorUserID: UUID? = nil,
        take: Int = 50
    ) async throws -> [PlaceReview] {
        var queryItems = [URLQueryItem(name: "take", value: String(take))]

        if let placeID {
            queryItems.append(URLQueryItem(name: "placeId", value: placeID.uuidString))
        }

        if let authorUserID {
            queryItems.append(URLQueryItem(name: "authorUserId", value: authorUserID.uuidString))
        }

        return try await apiClient.send(
            APIRequest<[PlaceReview]>(
                method: .get,
                path: "place-reviews",
                queryItems: queryItems
            )
        )
    }

    func fetchReview(id: UUID) async throws -> PlaceReview {
        try await apiClient.send(
            APIRequest<PlaceReview>(
                method: .get,
                path: "place-reviews/\(id.uuidString)"
            )
        )
    }

    func createReview(_ draft: PlaceReviewDraft) async throws -> PlaceReview {
        let payload = CreatePlaceReviewPayload(
            placeId: draft.placeId,
            visibility: draft.visibility,
            rating: draft.ratingOverall,
            title: draft.reviewText.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            body: draft.descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        )

        let review = try await apiClient.send(
            APIRequest<PlaceReview>(
                method: .post,
                path: "place-reviews",
                body: .json(AnyEncodable(payload)),
                acceptedStatusCodes: [201]
            )
        )

        if !draft.photoDataItems.isEmpty {
            do {
                try await uploadPhotos(draft.photoDataItems, to: review.id)
            } catch {
                try? await deleteReview(review)
                throw AppError.validationFailure(
                    "The review could not be saved because at least one photo failed to upload. Nothing was changed."
                )
            }

            return try await fetchReview(id: review.id)
        }

        return review
    }

    func updateReview(_ review: PlaceReview, with draft: PlaceReviewDraft) async throws -> PlaceReview {
        let payload = UpdatePlaceReviewPayload(
            visibility: draft.visibility,
            rating: draft.ratingOverall,
            title: draft.reviewText.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            body: draft.descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        )

        _ = try await apiClient.send(
            APIRequest<PlaceReview>(
                method: .patch,
                path: "place-reviews/\(review.id.uuidString)",
                body: .json(AnyEncodable(payload))
            )
        )

        do {
            try await uploadPhotos(draft.photoDataItems, to: review.id)
            try await deletePhotos(withIDs: draft.photoIDsToDelete)
        } catch {
            throw AppError.validationFailure(
                "Review details were saved, but TrustMap could not finish the photo changes. Refresh the place and try again."
            )
        }

        return try await fetchReview(id: review.id)
    }

    func deleteReview(_ review: PlaceReview) async throws {
        _ = try await apiClient.send(
            APIRequest<EmptyResponse>(
                method: .delete,
                path: "place-reviews/\(review.id.uuidString)",
                acceptedStatusCodes: [204]
            )
        )
    }

    private func uploadPhotos(_ photoDataItems: [Data], to reviewID: UUID) async throws {
        for item in photoDataItems {
            _ = try await photoRepository.uploadPlaceReviewPhoto(
                reviewID: reviewID,
                imageData: item
            )
        }
    }

    private func deletePhotos(withIDs photoIDs: [UUID]) async throws {
        for photoID in photoIDs {
            try await photoRepository.deletePhoto(id: photoID)
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
