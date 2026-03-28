import Foundation
import SwiftData

@MainActor
final class PhotoAssetRepository {
    private let persistenceController: PersistenceController
    private let storageService: LocalPhotoStorageService
    private let cloudKitSyncService: CloudKitSyncing

    init(
        persistenceController: PersistenceController,
        storageService: LocalPhotoStorageService,
        cloudKitSyncService: CloudKitSyncing
    ) {
        self.persistenceController = persistenceController
        self.storageService = storageService
        self.cloudKitSyncService = cloudKitSyncService
    }

    private var context: ModelContext {
        persistenceController.mainContext
    }

    func storePlaceReviewPhotos(
        _ dataItems: [Data],
        ownerUserID: UUID,
        placeID: UUID,
        placeReviewID: UUID
    ) throws -> [PhotoAsset] {
        var assets: [PhotoAsset] = []

        for data in dataItems {
            let reference = try storageService.storeImageData(data)
            let asset = PhotoAsset(
                ownerUserId: ownerUserID,
                placeId: placeID,
                placeReviewId: placeReviewID,
                assetReference: reference
            )
            context.insert(asset)
            assets.append(asset)
        }

        try saveChanges()

        for asset in assets {
            let url = storageService.fileURL(for: asset.assetReference)
            Task { await cloudKitSyncService.syncPhotoAsset(asset, fileURL: url) }
        }

        return assets
    }

    func storeDishPhoto(
        _ data: Data?,
        ownerUserID: UUID,
        placeID: UUID,
        dishReviewID: UUID
    ) throws -> PhotoAsset? {
        guard let data else {
            return nil
        }

        let reference = try storageService.storeImageData(data)
        let asset = PhotoAsset(
            ownerUserId: ownerUserID,
            placeId: placeID,
            dishReviewId: dishReviewID,
            assetReference: reference
        )
        context.insert(asset)
        try saveChanges()
        let url = storageService.fileURL(for: asset.assetReference)
        Task { await cloudKitSyncService.syncPhotoAsset(asset, fileURL: url) }
        return asset
    }

    func photos(for placeID: UUID) throws -> [PhotoAsset] {
        let descriptor = FetchDescriptor<PhotoAsset>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return try context.fetch(descriptor).filter { $0.placeId == placeID }
    }

    func photos(
        for placeID: UUID,
        visiblePlaceReviewIDs: Set<UUID>,
        visibleDishReviewIDs: Set<UUID>
    ) throws -> [PhotoAsset] {
        let descriptor = FetchDescriptor<PhotoAsset>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return try context.fetch(descriptor).filter { asset in
            guard asset.placeId == placeID else {
                return false
            }

            if let placeReviewId = asset.placeReviewId, visiblePlaceReviewIDs.contains(placeReviewId) {
                return true
            }

            if let dishReviewId = asset.dishReviewId, visibleDishReviewIDs.contains(dishReviewId) {
                return true
            }

            return false
        }
    }

    func assets(forPlaceReviewID reviewID: UUID) throws -> [PhotoAsset] {
        let descriptor = FetchDescriptor<PhotoAsset>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return try context.fetch(descriptor).filter { $0.placeReviewId == reviewID }
    }

    func assets(forDishReviewID reviewID: UUID) throws -> [PhotoAsset] {
        let descriptor = FetchDescriptor<PhotoAsset>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return try context.fetch(descriptor).filter { $0.dishReviewId == reviewID }
    }

    func imageData(for asset: PhotoAsset) -> Data? {
        storageService.imageData(for: asset.assetReference)
    }

    func removeStoredFiles(for assets: [PhotoAsset]) {
        for asset in assets {
            storageService.deleteImageIfPresent(for: asset.assetReference)
        }
    }

    private func saveChanges() throws {
        do {
            if context.hasChanges {
                try context.save()
            }
        } catch {
            throw AppError.persistenceFailure("Unable to save the selected photos.")
        }
    }
}
