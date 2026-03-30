import Foundation
import SwiftData

@MainActor
final class DishReviewRepository {
    private let persistenceController: PersistenceController
    private let cloudKitSyncService: CloudKitSyncService
    private let photoAssetRepository: PhotoAssetRepository

    init(
        persistenceController: PersistenceController,
        cloudKitSyncService: CloudKitSyncService,
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
                    && isVisible($0, viewerID: viewerID, friendIDs: friendIDs)
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
            visibility: draft.visibility,
            dishName: draft.dishName.trimmingCharacters(in: .whitespacesAndNewlines),
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
        review.visibility = draft.visibility
        review.dishName = draft.dishName.trimmingCharacters(in: .whitespacesAndNewlines)
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

        if let existingAsset = try photoAssetRepository.assets(forDishReviewID: review.id).first {
            let fileURL = photoAssetRepository.imageData(for: existingAsset).flatMap { _ in
                photoAssetRepository.storageFileURL(for: existingAsset)
            }
            Task { await cloudKitSyncService.syncPhotoAsset(existingAsset, fileURL: fileURL) }
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
        let reviewSnapshot = DishReview(
            id: review.id,
            placeId: review.placeId,
            authorUserId: review.authorUserId,
            placeReviewId: review.placeReviewId,
            visibility: review.visibility,
            dishName: review.dishName,
            dishRating: review.dishRating,
            dishReviewText: review.dishReviewText,
            price: review.price,
            createdAt: review.createdAt,
            updatedAt: review.updatedAt
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

        Task {
            for asset in relatedAssets {
                await cloudKitSyncService.deletePhotoAsset(asset)
            }
            for activity in relatedActivities {
                await cloudKitSyncService.deleteActivity(activity, ownerUserID: reviewSnapshot.authorUserId)
            }
            await cloudKitSyncService.deleteDishReview(reviewSnapshot)
        }
    }

    private func allReviews() throws -> [DishReview] {
        let descriptor = FetchDescriptor<DishReview>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        var seenReviewIDs = Set<UUID>()
        return try context.fetch(descriptor).filter { seenReviewIDs.insert($0.id).inserted }
    }

    private func activities(for referenceID: String, types: Set<ActivityItemType>) throws -> [ActivityItem] {
        let descriptor = FetchDescriptor<ActivityItem>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return try context.fetch(descriptor).filter {
            $0.referenceId == referenceID && types.contains($0.type)
        }
    }

    private func isVisible(_ review: DishReview, viewerID: UUID, friendIDs: Set<UUID>) -> Bool {
        if review.authorUserId == viewerID {
            return true
        }

        switch review.visibility {
        case .friendsOnly:
            return friendIDs.contains(review.authorUserId)
        case .onlyMe:
            return false
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
