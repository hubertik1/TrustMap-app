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

    private func allReviews() throws -> [DishReview] {
        let descriptor = FetchDescriptor<DishReview>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        return try context.fetch(descriptor)
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
