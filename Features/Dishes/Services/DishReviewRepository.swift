import Foundation

@MainActor
final class DishReviewRepository {
    private struct CreateDishReviewPayload: Encodable {
        let placeId: UUID
        let categoryId: UUID
        let placeReviewId: UUID?
        let visibility: VisibilityStatus
        let dishName: String
        let rating: Int
        let body: String?
        let priceAmount: Decimal?
        let currencyCode: String?
    }

    private struct UpdateDishReviewPayload: Encodable {
        let categoryId: UUID
        let visibility: VisibilityStatus
        let dishName: String
        let rating: Int
        let body: String?
        let priceAmount: Decimal?
        let currencyCode: String?
    }

    private let apiClient: APIClient
    private let photoRepository: PhotoRepository

    init(apiClient: APIClient, photoRepository: PhotoRepository) {
        self.apiClient = apiClient
        self.photoRepository = photoRepository
    }

    func fetchReviews(
        placeID: UUID? = nil,
        placeReviewID: UUID? = nil,
        authorUserID: UUID? = nil,
        take: Int = 50
    ) async throws -> [DishReview] {
        var queryItems = [URLQueryItem(name: "take", value: String(take))]

        if let placeID {
            queryItems.append(URLQueryItem(name: "placeId", value: placeID.uuidString))
        }

        if let placeReviewID {
            queryItems.append(URLQueryItem(name: "placeReviewId", value: placeReviewID.uuidString))
        }

        if let authorUserID {
            queryItems.append(URLQueryItem(name: "authorUserId", value: authorUserID.uuidString))
        }

        return try await apiClient.send(
            APIRequest<[DishReview]>(
                method: .get,
                path: "dish-reviews",
                queryItems: queryItems
            )
        )
    }

    func fetchReview(id: UUID) async throws -> DishReview {
        try await apiClient.send(
            APIRequest<DishReview>(
                method: .get,
                path: "dish-reviews/\(id.uuidString)"
            )
        )
    }

    func createReview(_ draft: DishReviewDraft) async throws -> DishReview {
        guard let categoryId = draft.selectedCategoryId else {
            throw AppError.validationFailure(L10n.chooseACategoryForThisPlace)
        }

        let payload = CreateDishReviewPayload(
            placeId: draft.placeId,
            categoryId: categoryId,
            placeReviewId: draft.placeReviewId,
            visibility: draft.visibility,
            dishName: draft.dishName.trimmingCharacters(in: .whitespacesAndNewlines),
            rating: draft.dishRating,
            body: draft.dishReviewText.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            priceAmount: draft.price.map { Decimal($0) },
            currencyCode: draft.price == nil ? nil : Locale.current.currency?.identifier
        )

        guard !payload.dishName.isEmpty else {
            throw AppError.validationFailure(L10n.enterADishName)
        }

        let review = try await apiClient.send(
            APIRequest<DishReview>(
                method: .post,
                path: "dish-reviews",
                body: .json(AnyEncodable(payload)),
                acceptedStatusCodes: [201]
            )
        )

        if let photoData = draft.photoData {
            do {
                _ = try await photoRepository.uploadDishReviewPhoto(reviewID: review.id, imageData: photoData)
            } catch {
                try? await deleteReview(review)
                throw AppError.validationFailure(
                    L10n.theDishReviewCouldNotBeSavedBecauseThePhotoUploadFailedNothingWasChanged
                )
            }

            return try await fetchReview(id: review.id)
        }

        return review
    }

    func updateReview(_ review: DishReview, with draft: DishReviewDraft) async throws -> DishReview {
        guard let categoryId = draft.selectedCategoryId else {
            throw AppError.validationFailure(L10n.chooseACategoryForThisPlace)
        }

        let payload = UpdateDishReviewPayload(
            categoryId: categoryId,
            visibility: draft.visibility,
            dishName: draft.dishName.trimmingCharacters(in: .whitespacesAndNewlines),
            rating: draft.dishRating,
            body: draft.dishReviewText.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            priceAmount: draft.price.map { Decimal($0) },
            currencyCode: draft.price == nil ? nil : Locale.current.currency?.identifier
        )

        guard !payload.dishName.isEmpty else {
            throw AppError.validationFailure(L10n.enterADishName)
        }

        _ = try await apiClient.send(
            APIRequest<DishReview>(
                method: .patch,
                path: "dish-reviews/\(review.id.uuidString)",
                body: .json(AnyEncodable(payload))
            )
        )

        do {
            if let photoData = draft.photoData {
                _ = try await photoRepository.uploadDishReviewPhoto(reviewID: review.id, imageData: photoData)
            }

            for photoID in draft.photoIDsToDelete {
                try await photoRepository.deletePhoto(id: photoID)
            }
        } catch {
            throw AppError.validationFailure(
                L10n.dishReviewDetailsWereSavedButTrustmapCouldNotFinishThePhotoChangesRefreshThePlaceAndTryAgain
            )
        }

        return try await fetchReview(id: review.id)
    }

    func deleteReview(_ review: DishReview) async throws {
        _ = try await apiClient.send(
            APIRequest<EmptyResponse>(
                method: .delete,
                path: "dish-reviews/\(review.id.uuidString)",
                acceptedStatusCodes: [204]
            )
        )
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
