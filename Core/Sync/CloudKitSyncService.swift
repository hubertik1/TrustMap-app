import CloudKit
import Foundation
import OSLog

@MainActor
protocol CloudKitSyncing: AnyObject {
    func syncUser(_ user: User) async
    func syncFriendRelation(_ relation: FriendRelation) async
    func syncPlace(_ place: Place) async
    func syncCustomCategory(_ category: CustomCategory) async
    func syncPlaceCategoryAssignment(_ assignment: PlaceCategoryAssignment) async
    func syncPlaceReview(_ review: PlaceReview) async
    func syncDishReview(_ review: DishReview) async
    func syncPhotoAsset(_ asset: PhotoAsset, fileURL: URL?) async
    func syncActivity(_ item: ActivityItem) async
}

@MainActor
final class CloudKitSyncService: CloudKitSyncing {
    private let logger = Logger(subsystem: "TrustMap", category: "CloudKitSync")
    private let forceDisabled: Bool

    private lazy var database: CKDatabase? = {
        guard !forceDisabled else {
            return nil
        }

        return CKContainer.default().privateCloudDatabase
    }()

    init(forceDisabled: Bool = false) {
        self.forceDisabled = forceDisabled
    }

    func syncUser(_ user: User) async {
        let record = CKRecord(recordType: "User", recordID: .init(recordName: user.id.uuidString))
        record["appleUserId"] = user.appleUserId as CKRecordValue
        record["displayName"] = user.displayName as CKRecordValue
        record["bio"] = user.bio as CKRecordValue?
        record["avatarReference"] = user.avatarReference as CKRecordValue?
        record["createdAt"] = user.createdAt as CKRecordValue
        await save(record)
    }

    func syncFriendRelation(_ relation: FriendRelation) async {
        let record = CKRecord(recordType: "FriendRelation", recordID: .init(recordName: relation.id.uuidString))
        record["ownerUserId"] = relation.ownerUserId.uuidString as CKRecordValue
        record["targetUserId"] = relation.targetUserId.uuidString as CKRecordValue
        record["status"] = relation.status.rawValue as CKRecordValue
        record["createdAt"] = relation.createdAt as CKRecordValue
        await save(record)
    }

    func syncPlace(_ place: Place) async {
        let record = CKRecord(recordType: "Place", recordID: .init(recordName: place.id.uuidString))
        record["appleMapsPlaceId"] = place.appleMapsPlaceId as CKRecordValue?
        record["name"] = place.name as CKRecordValue
        record["latitude"] = place.latitude as CKRecordValue
        record["longitude"] = place.longitude as CKRecordValue
        record["address"] = place.address as CKRecordValue
        record["sourceType"] = place.sourceType.rawValue as CKRecordValue
        record["createdByUserId"] = place.createdByUserId?.uuidString as CKRecordValue?
        record["createdAt"] = place.createdAt as CKRecordValue
        await save(record)
    }

    func syncCustomCategory(_ category: CustomCategory) async {
        let record = CKRecord(recordType: "CustomCategory", recordID: .init(recordName: category.id.uuidString))
        record["ownerUserId"] = category.ownerUserId.uuidString as CKRecordValue
        record["name"] = category.name as CKRecordValue
        record["iconName"] = category.iconName as CKRecordValue?
        record["createdAt"] = category.createdAt as CKRecordValue
        await save(record)
    }

    func syncPlaceCategoryAssignment(_ assignment: PlaceCategoryAssignment) async {
        let record = CKRecord(recordType: "PlaceCategoryAssignment", recordID: .init(recordName: assignment.id.uuidString))
        record["placeId"] = assignment.placeId.uuidString as CKRecordValue
        record["categoryId"] = assignment.categoryId.uuidString as CKRecordValue
        record["assignedByUserId"] = assignment.assignedByUserId.uuidString as CKRecordValue
        await save(record)
    }

    func syncPlaceReview(_ review: PlaceReview) async {
        let record = CKRecord(recordType: "PlaceReview", recordID: .init(recordName: review.id.uuidString))
        record["placeId"] = review.placeId.uuidString as CKRecordValue
        record["authorUserId"] = review.authorUserId.uuidString as CKRecordValue
        record["ratingOverall"] = review.ratingOverall as CKRecordValue
        record["reviewText"] = review.reviewText as CKRecordValue
        record["descriptionText"] = review.descriptionText as CKRecordValue
        record["visibility"] = review.visibility.rawValue as CKRecordValue
        record["createdAt"] = review.createdAt as CKRecordValue
        record["updatedAt"] = review.updatedAt as CKRecordValue
        await save(record)
    }

    func syncDishReview(_ review: DishReview) async {
        let record = CKRecord(recordType: "DishReview", recordID: .init(recordName: review.id.uuidString))
        record["placeId"] = review.placeId.uuidString as CKRecordValue
        record["authorUserId"] = review.authorUserId.uuidString as CKRecordValue
        record["placeReviewId"] = review.placeReviewId?.uuidString as CKRecordValue?
        record["dishName"] = review.dishName as CKRecordValue
        record["dishRating"] = review.dishRating as CKRecordValue
        record["dishReviewText"] = review.dishReviewText as CKRecordValue
        if let price = review.price {
            record["price"] = price as CKRecordValue
        }
        record["createdAt"] = review.createdAt as CKRecordValue
        record["updatedAt"] = review.updatedAt as CKRecordValue
        await save(record)
    }

    func syncPhotoAsset(_ asset: PhotoAsset, fileURL: URL?) async {
        let record = CKRecord(recordType: "PhotoAsset", recordID: .init(recordName: asset.id.uuidString))
        record["ownerUserId"] = asset.ownerUserId.uuidString as CKRecordValue
        record["placeId"] = asset.placeId?.uuidString as CKRecordValue?
        record["placeReviewId"] = asset.placeReviewId?.uuidString as CKRecordValue?
        record["dishReviewId"] = asset.dishReviewId?.uuidString as CKRecordValue?
        record["assetReference"] = asset.assetReference as CKRecordValue
        record["createdAt"] = asset.createdAt as CKRecordValue

        if let fileURL {
            record["binaryAsset"] = CKAsset(fileURL: fileURL)
        }

        await save(record)
    }

    func syncActivity(_ item: ActivityItem) async {
        let record = CKRecord(recordType: "ActivityItem", recordID: .init(recordName: item.id.uuidString))
        record["actorUserId"] = item.actorUserId.uuidString as CKRecordValue
        record["type"] = item.type.rawValue as CKRecordValue
        record["referenceId"] = item.referenceId as CKRecordValue
        record["createdAt"] = item.createdAt as CKRecordValue
        await save(record)
    }

    private func save(_ record: CKRecord) async {
        guard let database else {
            return
        }

        do {
            _ = try await database.save(record)
        } catch {
            logger.error("CloudKit sync skipped: \(error.localizedDescription, privacy: .public)")
        }
    }
}
