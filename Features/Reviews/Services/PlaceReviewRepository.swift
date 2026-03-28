import Foundation
import SwiftData

@MainActor
final class PlaceReviewRepository {
    private let persistenceController: PersistenceController
    private let cloudKitSyncService: CloudKitSyncing
    private let photoAssetRepository: PhotoAssetRepository
    private let categoryRepository: CategoryRepository

    init(
        persistenceController: PersistenceController,
        cloudKitSyncService: CloudKitSyncing,
        photoAssetRepository: PhotoAssetRepository,
        categoryRepository: CategoryRepository
    ) {
        self.persistenceController = persistenceController
        self.cloudKitSyncService = cloudKitSyncService
        self.photoAssetRepository = photoAssetRepository
        self.categoryRepository = categoryRepository
    }

    private var context: ModelContext {
        persistenceController.mainContext
    }

    func reviews(for placeID: UUID, visibleTo viewerID: UUID, friendIDs: Set<UUID>) throws -> [PlaceReview] {
        try allReviews()
            .filter { $0.placeId == placeID && isVisible($0, viewerID: viewerID, friendIDs: friendIDs) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func reviews(authoredBy authorIDs: Set<UUID>, ratingRange: ClosedRange<Int>) throws -> [PlaceReview] {
        try allReviews()
            .filter { authorIDs.contains($0.authorUserId) && ratingRange.contains($0.ratingOverall) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func reviews(
        authoredBy authorIDs: Set<UUID>,
        visibleTo viewerID: UUID,
        friendIDs: Set<UUID>,
        ratingRange: ClosedRange<Int>
    ) throws -> [PlaceReview] {
        try allReviews()
            .filter {
                authorIDs.contains($0.authorUserId)
                    && ratingRange.contains($0.ratingOverall)
                    && isVisible($0, viewerID: viewerID, friendIDs: friendIDs)
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func reviews(authoredBy userID: UUID) throws -> [PlaceReview] {
        try allReviews()
            .filter { $0.authorUserId == userID }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func review(for placeID: UUID, authoredBy userID: UUID) throws -> PlaceReview? {
        try allReviews().first { $0.placeId == placeID && $0.authorUserId == userID }
    }

    func addReview(_ draft: PlaceReviewDraft) throws -> PlaceReview {
        guard (1...10).contains(draft.ratingOverall) else {
            throw AppError.validationFailure("Place ratings must be between 1 and 10.")
        }

        if try review(for: draft.placeId, authoredBy: draft.authorUserId) != nil {
            throw AppError.validationFailure("You've already reviewed this place. Edit your review instead.")
        }

        let review = PlaceReview(
            placeId: draft.placeId,
            authorUserId: draft.authorUserId,
            ratingOverall: draft.ratingOverall,
            reviewText: draft.reviewText.trimmingCharacters(in: .whitespacesAndNewlines),
            descriptionText: draft.descriptionText.trimmingCharacters(in: .whitespacesAndNewlines),
            visibility: draft.visibility
        )
        context.insert(review)
        try saveChanges(message: "Unable to save the place review.")

        if let selectedCategoryId = draft.selectedCategoryId {
            try categoryRepository.assignCategory(selectedCategoryId, to: draft.placeId, assignedBy: draft.authorUserId)
        }

        let storedAssets = try photoAssetRepository.storePlaceReviewPhotos(
            draft.photoDataItems,
            ownerUserID: draft.authorUserId,
            placeID: draft.placeId,
            placeReviewID: review.id
        )

        let reviewActivity = ActivityItem(
            actorUserId: draft.authorUserId,
            type: .placeReviewAdded,
            referenceId: review.id.uuidString
        )
        context.insert(reviewActivity)

        if !storedAssets.isEmpty {
            let photoActivity = ActivityItem(
                actorUserId: draft.authorUserId,
                type: .photoAdded,
                referenceId: review.id.uuidString
            )
            context.insert(photoActivity)
        }

        try saveChanges(message: "Unable to save the activity for this review.")

        Task {
            await cloudKitSyncService.syncPlaceReview(review)
            await cloudKitSyncService.syncActivity(reviewActivity)
        }

        return review
    }

    func updateReview(_ review: PlaceReview, with draft: PlaceReviewDraft) throws -> PlaceReview {
        guard (1...10).contains(draft.ratingOverall) else {
            throw AppError.validationFailure("Place ratings must be between 1 and 10.")
        }

        review.ratingOverall = draft.ratingOverall
        review.reviewText = draft.reviewText.trimmingCharacters(in: .whitespacesAndNewlines)
        review.descriptionText = draft.descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        review.visibility = draft.visibility
        review.updatedAt = .now
        try saveChanges(message: "Unable to update the place review.")

        if let selectedCategoryId = draft.selectedCategoryId {
            try categoryRepository.assignCategory(selectedCategoryId, to: draft.placeId, assignedBy: draft.authorUserId)
        } else {
            try categoryRepository.removeAssignments(for: draft.placeId, assignedBy: draft.authorUserId)
        }

        let storedAssets = try photoAssetRepository.storePlaceReviewPhotos(
            draft.photoDataItems,
            ownerUserID: draft.authorUserId,
            placeID: draft.placeId,
            placeReviewID: review.id
        )

        if !storedAssets.isEmpty {
            let photoActivity = ActivityItem(
                actorUserId: draft.authorUserId,
                type: .photoAdded,
                referenceId: review.id.uuidString
            )
            context.insert(photoActivity)
            try saveChanges(message: "Unable to save the activity for this review.")
            Task { await cloudKitSyncService.syncActivity(photoActivity) }
        }

        Task { await cloudKitSyncService.syncPlaceReview(review) }
        return review
    }

    func deleteReview(_ review: PlaceReview) throws {
        let relatedAssets = try photoAssetRepository.assets(forPlaceReviewID: review.id)
        let relatedActivities = try activities(
            for: review.id.uuidString,
            types: [.placeReviewAdded, .photoAdded]
        )

        try categoryRepository.removeAssignments(for: review.placeId, assignedBy: review.authorUserId)

        for asset in relatedAssets {
            context.delete(asset)
        }

        for activity in relatedActivities {
            context.delete(activity)
        }

        context.delete(review)
        try saveChanges(message: "Unable to delete the place review.")
        photoAssetRepository.removeStoredFiles(for: relatedAssets)
    }

    func averageRating(for placeID: UUID, visibleTo viewerID: UUID, friendIDs: Set<UUID>) throws -> Double? {
        let reviews = try reviews(for: placeID, visibleTo: viewerID, friendIDs: friendIDs)
        guard !reviews.isEmpty else {
            return nil
        }

        let total = reviews.reduce(0) { $0 + $1.ratingOverall }
        return Double(total) / Double(reviews.count)
    }

    private func isVisible(_ review: PlaceReview, viewerID: UUID, friendIDs: Set<UUID>) -> Bool {
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

    private func allReviews() throws -> [PlaceReview] {
        let descriptor = FetchDescriptor<PlaceReview>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
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
