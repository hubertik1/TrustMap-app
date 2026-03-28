import Foundation
import SwiftData

@MainActor
final class DishReviewRepository {
    private let persistenceController: PersistenceController
    private let cloudKitSyncService: CloudKitSyncing
    private let photoAssetRepository: PhotoAssetRepository

    init(
        persistenceController: PersistenceController,
        cloudKitSyncService: CloudKitSyncing,
        photoAssetRepository: PhotoAssetRepository
    ) {
        self.persistenceController = persistenceController
        self.cloudKitSyncService = cloudKitSyncService
        self.photoAssetRepository = photoAssetRepository
    }

    private var context: ModelContext {
        persistenceController.mainContext
    }

    func reviews(for placeID: UUID, visibleTo viewerID: UUID, friendIDs: Set<UUID>) throws -> [DishReview] {
        try allReviews()
            .filter {
                $0.placeId == placeID
                    && ($0.authorUserId == viewerID || friendIDs.contains($0.authorUserId))
            }
            .sorted { $0.dishRating > $1.dishRating }
    }

    func reviews(authoredBy userID: UUID) throws -> [DishReview] {
        try allReviews()
            .filter { $0.authorUserId == userID }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func review(withID reviewID: UUID) throws -> DishReview? {
        try allReviews().first { $0.id == reviewID }
    }

    func addReview(_ draft: DishReviewDraft) throws -> DishReview {
        guard (1...10).contains(draft.dishRating) else {
            throw AppError.validationFailure("Dish ratings must be between 1 and 10.")
        }

        let review = DishReview(
            placeId: draft.placeId,
            authorUserId: draft.authorUserId,
            placeReviewId: draft.placeReviewId,
            dishName: draft.dishName.trimmingCharacters(in: .whitespacesAndNewlines),
            dishCategory: draft.dishCategory?.trimmingCharacters(in: .whitespacesAndNewlines),
            dishRating: draft.dishRating,
            dishReviewText: draft.dishReviewText.trimmingCharacters(in: .whitespacesAndNewlines),
            price: draft.price
        )
        context.insert(review)
        try saveChanges(message: "Unable to save the dish review.")

        let photoAsset = try photoAssetRepository.storeDishPhoto(
            draft.photoData,
            ownerUserID: draft.authorUserId,
            placeID: draft.placeId,
            dishReviewID: review.id
        )

        let reviewActivity = ActivityItem(
            actorUserId: draft.authorUserId,
            type: .dishReviewAdded,
            referenceId: review.id.uuidString
        )
        context.insert(reviewActivity)

        if photoAsset != nil {
            let photoActivity = ActivityItem(
                actorUserId: draft.authorUserId,
                type: .photoAdded,
                referenceId: review.id.uuidString
            )
            context.insert(photoActivity)
        }

        try saveChanges(message: "Unable to save the dish activity.")

        Task {
            await cloudKitSyncService.syncDishReview(review)
            await cloudKitSyncService.syncActivity(reviewActivity)
        }

        return review
    }

    func updateReview(_ review: DishReview, with draft: DishReviewDraft) throws -> DishReview {
        guard (1...10).contains(draft.dishRating) else {
            throw AppError.validationFailure("Dish ratings must be between 1 and 10.")
        }

        review.placeReviewId = draft.placeReviewId
        review.dishName = draft.dishName.trimmingCharacters(in: .whitespacesAndNewlines)
        review.dishCategory = draft.dishCategory?.trimmingCharacters(in: .whitespacesAndNewlines)
        review.dishRating = draft.dishRating
        review.dishReviewText = draft.dishReviewText.trimmingCharacters(in: .whitespacesAndNewlines)
        review.price = draft.price
        review.updatedAt = .now
        try saveChanges(message: "Unable to update the dish review.")

        if let photoData = draft.photoData {
            let relatedAssets = try photoAssetRepository.assets(forDishReviewID: review.id)

            for asset in relatedAssets {
                context.delete(asset)
            }

            try saveChanges(message: "Unable to replace the dish photo.")
            photoAssetRepository.removeStoredFiles(for: relatedAssets)

            _ = try photoAssetRepository.storeDishPhoto(
                photoData,
                ownerUserID: draft.authorUserId,
                placeID: draft.placeId,
                dishReviewID: review.id
            )

            let photoActivity = ActivityItem(
                actorUserId: draft.authorUserId,
                type: .photoAdded,
                referenceId: review.id.uuidString
            )
            context.insert(photoActivity)
            try saveChanges(message: "Unable to save the dish activity.")
            Task { await cloudKitSyncService.syncActivity(photoActivity) }
        }

        Task { await cloudKitSyncService.syncDishReview(review) }
        return review
    }

    func deleteReview(_ review: DishReview) throws {
        let relatedAssets = try photoAssetRepository.assets(forDishReviewID: review.id)
        let relatedActivities = try activities(
            for: review.id.uuidString,
            types: [.dishReviewAdded, .photoAdded]
        )

        for asset in relatedAssets {
            context.delete(asset)
        }

        for activity in relatedActivities {
            context.delete(activity)
        }

        context.delete(review)
        try saveChanges(message: "Unable to delete the dish review.")
        photoAssetRepository.removeStoredFiles(for: relatedAssets)
    }

    private func allReviews() throws -> [DishReview] {
        let descriptor = FetchDescriptor<DishReview>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        return try context.fetch(descriptor)
    }

    private func activities(for referenceID: String, types: Set<ActivityItemType>) throws -> [ActivityItem] {
        let descriptor = FetchDescriptor<ActivityItem>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return try context.fetch(descriptor).filter {
            $0.referenceId == referenceID && types.contains($0.type)
        }
    }

    private func saveChanges(message: String) throws {
        do {
            if context.hasChanges {
                try context.save()
            }
        } catch {
            throw AppError.persistenceFailure(message)
        }
    }
}
