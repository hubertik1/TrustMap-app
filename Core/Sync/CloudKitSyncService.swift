import CloudKit
import Foundation
import OSLog
import SwiftData

@MainActor
final class CloudKitSyncService {
    private enum RecordType {
        static let user = "User"
        static let place = "Place"
        static let customCategory = "CustomCategory"
        static let placeCategoryAssignment = "PlaceCategoryAssignment"
        static let placeReview = "PlaceReview"
        static let dishReview = "DishReview"
        static let photoAsset = "PhotoAsset"
        static let activityItem = "ActivityItem"
    }

    private enum FieldKey {
        static let id = "id"
        static let appleUserId = "appleUserId"
        static let displayName = "displayName"
        static let bio = "bio"
        static let avatarReference = "avatarReference"
        static let cloudKitUserRecordName = "cloudKitUserRecordName"
        static let sharedContentShareRecordName = "sharedContentShareRecordName"
        static let sharedContentShareURL = "sharedContentShareURL"
        static let placeId = "placeId"
        static let authorUserId = "authorUserId"
        static let ownerUserId = "ownerUserId"
        static let createdByUserId = "createdByUserId"
        static let assignedByUserId = "assignedByUserId"
        static let categoryId = "categoryId"
        static let ratingOverall = "ratingOverall"
        static let reviewText = "reviewText"
        static let descriptionText = "descriptionText"
        static let visibility = "visibility"
        static let placeReviewId = "placeReviewId"
        static let dishName = "dishName"
        static let dishRating = "dishRating"
        static let dishReviewText = "dishReviewText"
        static let price = "price"
        static let assetReference = "assetReference"
        static let binaryAsset = "binaryAsset"
        static let actorUserId = "actorUserId"
        static let type = "type"
        static let referenceId = "referenceId"
        static let name = "name"
        static let iconName = "iconName"
        static let appleMapsPlaceId = "appleMapsPlaceId"
        static let latitude = "latitude"
        static let longitude = "longitude"
        static let address = "address"
        static let sourceType = "sourceType"
        static let createdAt = "createdAt"
        static let updatedAt = "updatedAt"
    }

    private enum Scope: CaseIterable {
        case privateOnly
        case shared
    }

    private struct RemotePhotoRecord {
        let id: UUID
        let ownerUserId: UUID
        let placeId: UUID?
        let placeReviewId: UUID?
        let dishReviewId: UUID?
        let createdAt: Date
        let binaryAssetURL: URL?
    }

    private struct RefreshState {
        let timestamp: Date
        let friendIDs: Set<UUID>
    }

    private let logger = Logger(subsystem: "TrustMap", category: "CloudKitSync")
    private let refreshCooldown: TimeInterval = 60
    private let refreshFailureCooldown: TimeInterval = 90
    private let shareAcceptanceFailureCooldown: TimeInterval = 300
    private let persistenceController: PersistenceController
    private let photoStorageService: LocalPhotoStorageService
    private let forceDisabled: Bool
    private let container: CKContainer
    private var refreshStatesByViewerID: [UUID: RefreshState] = [:]
    private var backfilledViewerIDs = Set<UUID>()
    private var refreshFailureTimestampsByViewerID: [UUID: Date] = [:]
    private var acceptedShareURLs = Set<String>()
    private var shareAcceptanceFailureTimestampsByURL: [String: Date] = [:]

    init(
        persistenceController: PersistenceController,
        photoStorageService: LocalPhotoStorageService,
        forceDisabled: Bool = false,
        container: CKContainer = .default()
    ) {
        self.persistenceController = persistenceController
        self.photoStorageService = photoStorageService
        self.forceDisabled = forceDisabled
        self.container = container
    }

    private var context: ModelContext {
        persistenceController.mainContext
    }

    private var privateDatabase: CKDatabase? {
        guard !forceDisabled else {
            return nil
        }

        return container.privateCloudDatabase
    }

    private var sharedDatabase: CKDatabase? {
        guard !forceDisabled else {
            return nil
        }

        return container.sharedCloudDatabase
    }

    func prepareSharingProfile(for user: User) async throws {
        guard !forceDisabled else {
            return
        }

        if let currentUserRecordID = try await fetchCurrentUserRecordID() {
            user.cloudKitUserRecordName = currentUserRecordID.recordName
        }

        let share = try await ensureSharedContentShare(for: user)
        user.sharedContentShareRecordName = share.recordID.recordName
        user.sharedContentShareURL = share.url?.absoluteString
        try saveChanges(message: "Unable to save the sharing profile.")
    }

    func refreshFriendVisibleContent(for viewer: User, friends: [User]) async throws {
        guard !forceDisabled else {
            return
        }

        let friendIDs = Set(friends.map(\.id))
        if let existingState = refreshStatesByViewerID[viewer.id],
           existingState.friendIDs == friendIDs,
           Date().timeIntervalSince(existingState.timestamp) < refreshCooldown {
            return
        }

        try await prepareSharingProfile(for: viewer)
        await syncUser(viewer)
        if !backfilledViewerIDs.contains(viewer.id) {
            await backfillLocalContent(for: viewer)
            backfilledViewerIDs.insert(viewer.id)
        }
        try await reconcileShareParticipants(for: viewer, friends: friends)
        await acceptFriendSharesIfNeeded(friends)
        try await mergeSharedContent(from: friends)
        try purgeStaleSharedCache(viewerID: viewer.id, friendIDs: Set(friends.map(\.id)))
        refreshStatesByViewerID[viewer.id] = RefreshState(timestamp: .now, friendIDs: friendIDs)
    }

    func refreshFriendVisibleContentIfPossible(for viewer: User, friends: [User]) async {
        if let lastFailure = refreshFailureTimestampsByViewerID[viewer.id],
           Date().timeIntervalSince(lastFailure) < refreshFailureCooldown {
            return
        }

        do {
            try await refreshFriendVisibleContent(for: viewer, friends: friends)
            refreshFailureTimestampsByViewerID[viewer.id] = nil
        } catch {
            refreshFailureTimestampsByViewerID[viewer.id] = .now
            logger.error("Unable to refresh friend-visible content: \(error.localizedDescription, privacy: .public)")
        }
    }

    func syncUser(_ user: User) async {
        guard let privateDatabase else {
            return
        }

        let record = CKRecord(recordType: RecordType.user, recordID: .init(recordName: user.id.uuidString))
        record[FieldKey.id] = user.id.uuidString as CKRecordValue
        record[FieldKey.appleUserId] = user.appleUserId as CKRecordValue
        record[FieldKey.displayName] = user.displayName as CKRecordValue
        record[FieldKey.bio] = user.bio as CKRecordValue?
        record[FieldKey.avatarReference] = user.avatarReference as CKRecordValue?
        record[FieldKey.cloudKitUserRecordName] = user.cloudKitUserRecordName as CKRecordValue?
        record[FieldKey.sharedContentShareRecordName] = user.sharedContentShareRecordName as CKRecordValue?
        record[FieldKey.sharedContentShareURL] = user.sharedContentShareURL as CKRecordValue?
        record[FieldKey.createdAt] = user.createdAt as CKRecordValue

        do {
            _ = try await saveRecord(in: privateDatabase, record: record)
        } catch {
            logger.error("Unable to sync user content profile: \(error.localizedDescription, privacy: .public)")
        }
    }

    func syncFriendInvite(_ invite: FriendInvite) async {
        _ = invite
    }

    func syncFriendship(_ friendship: Friendship) async {
        _ = friendship
    }

    func syncPlace(_ place: Place) async {
        guard let ownerUserID = place.createdByUserId else {
            return
        }

        await upsertContentRecord(
            recordType: RecordType.place,
            recordID: place.id.uuidString,
            ownerUserID: ownerUserID,
            scopes: Set(Scope.allCases)
        ) { record in
            record[FieldKey.appleMapsPlaceId] = place.appleMapsPlaceId as CKRecordValue?
            record[FieldKey.name] = place.name as CKRecordValue
            record[FieldKey.latitude] = place.latitude as CKRecordValue
            record[FieldKey.longitude] = place.longitude as CKRecordValue
            record[FieldKey.address] = place.address as CKRecordValue
            record[FieldKey.sourceType] = place.sourceType.rawValue as CKRecordValue
            record[FieldKey.createdByUserId] = ownerUserID.uuidString as CKRecordValue
            record[FieldKey.createdAt] = place.createdAt as CKRecordValue
        }
    }

    func syncCustomCategory(_ category: CustomCategory) async {
        await upsertContentRecord(
            recordType: RecordType.customCategory,
            recordID: category.id.uuidString,
            ownerUserID: category.ownerUserId,
            scopes: Set(Scope.allCases)
        ) { record in
            record[FieldKey.ownerUserId] = category.ownerUserId.uuidString as CKRecordValue
            record[FieldKey.name] = category.name as CKRecordValue
            record[FieldKey.iconName] = category.iconName as CKRecordValue?
            record[FieldKey.createdAt] = category.createdAt as CKRecordValue
        }
    }

    func syncPlaceCategoryAssignment(_ assignment: PlaceCategoryAssignment) async {
        await upsertContentRecord(
            recordType: RecordType.placeCategoryAssignment,
            recordID: assignment.id.uuidString,
            ownerUserID: assignment.assignedByUserId,
            scopes: Set(Scope.allCases)
        ) { record in
            record[FieldKey.placeId] = assignment.placeId.uuidString as CKRecordValue
            record[FieldKey.categoryId] = assignment.categoryId.uuidString as CKRecordValue
            record[FieldKey.assignedByUserId] = assignment.assignedByUserId.uuidString as CKRecordValue
        }
    }

    func syncPlaceReview(_ review: PlaceReview) async {
        let targetScope = scope(for: review.visibility)
        await upsertContentRecord(
            recordType: RecordType.placeReview,
            recordID: review.id.uuidString,
            ownerUserID: review.authorUserId,
            scopes: [targetScope]
        ) { record in
            record[FieldKey.placeId] = review.placeId.uuidString as CKRecordValue
            record[FieldKey.authorUserId] = review.authorUserId.uuidString as CKRecordValue
            record[FieldKey.ratingOverall] = review.ratingOverall as CKRecordValue
            record[FieldKey.reviewText] = review.reviewText as CKRecordValue
            record[FieldKey.descriptionText] = review.descriptionText as CKRecordValue
            record[FieldKey.visibility] = review.visibility.rawValue as CKRecordValue
            record[FieldKey.createdAt] = review.createdAt as CKRecordValue
            record[FieldKey.updatedAt] = review.updatedAt as CKRecordValue
        }
        await deleteContentRecord(
            recordType: RecordType.placeReview,
            recordID: review.id.uuidString,
            ownerUserID: review.authorUserId,
            scopes: [oppositeScope(of: targetScope)]
        )
    }

    func syncDishReview(_ review: DishReview) async {
        let targetScope = scope(for: review.visibility)
        await upsertContentRecord(
            recordType: RecordType.dishReview,
            recordID: review.id.uuidString,
            ownerUserID: review.authorUserId,
            scopes: [targetScope]
        ) { record in
            record[FieldKey.placeId] = review.placeId.uuidString as CKRecordValue
            record[FieldKey.authorUserId] = review.authorUserId.uuidString as CKRecordValue
            record[FieldKey.placeReviewId] = review.placeReviewId?.uuidString as CKRecordValue?
            record[FieldKey.visibility] = review.visibility.rawValue as CKRecordValue
            record[FieldKey.dishName] = review.dishName as CKRecordValue
            record[FieldKey.dishRating] = review.dishRating as CKRecordValue
            record[FieldKey.dishReviewText] = review.dishReviewText as CKRecordValue
            if let price = review.price {
                record[FieldKey.price] = price as CKRecordValue
            }
            record[FieldKey.createdAt] = review.createdAt as CKRecordValue
            record[FieldKey.updatedAt] = review.updatedAt as CKRecordValue
        }
        await deleteContentRecord(
            recordType: RecordType.dishReview,
            recordID: review.id.uuidString,
            ownerUserID: review.authorUserId,
            scopes: [oppositeScope(of: targetScope)]
        )
    }

    func syncPhotoAsset(_ asset: PhotoAsset, fileURL: URL?) async {
        let visibility = visibility(for: asset)
        let targetScope = scope(for: visibility)
        await upsertContentRecord(
            recordType: RecordType.photoAsset,
            recordID: asset.id.uuidString,
            ownerUserID: asset.ownerUserId,
            scopes: [targetScope]
        ) { record in
            record[FieldKey.ownerUserId] = asset.ownerUserId.uuidString as CKRecordValue
            record[FieldKey.placeId] = asset.placeId?.uuidString as CKRecordValue?
            record[FieldKey.placeReviewId] = asset.placeReviewId?.uuidString as CKRecordValue?
            record[FieldKey.assetReference] = asset.assetReference as CKRecordValue
            record[FieldKey.createdAt] = asset.createdAt as CKRecordValue
            record["dishReviewId"] = asset.dishReviewId?.uuidString as CKRecordValue?
            if let fileURL {
                record[FieldKey.binaryAsset] = CKAsset(fileURL: fileURL)
            }
        }
        await deleteContentRecord(
            recordType: RecordType.photoAsset,
            recordID: asset.id.uuidString,
            ownerUserID: asset.ownerUserId,
            scopes: [oppositeScope(of: targetScope)]
        )
    }

    func syncActivity(_ item: ActivityItem) async {
        guard let ownerUserID = activityOwnerUserID(for: item) else {
            return
        }

        let targetScope = scope(for: visibility(for: item))
        await upsertContentRecord(
            recordType: RecordType.activityItem,
            recordID: item.id.uuidString,
            ownerUserID: ownerUserID,
            scopes: [targetScope]
        ) { record in
            record[FieldKey.actorUserId] = item.actorUserId.uuidString as CKRecordValue
            record[FieldKey.type] = item.type.rawValue as CKRecordValue
            record[FieldKey.referenceId] = item.referenceId as CKRecordValue
            record[FieldKey.createdAt] = item.createdAt as CKRecordValue
        }
        await deleteContentRecord(
            recordType: RecordType.activityItem,
            recordID: item.id.uuidString,
            ownerUserID: ownerUserID,
            scopes: [oppositeScope(of: targetScope)]
        )
    }

    func deletePlaceReview(_ review: PlaceReview) async {
        await deleteContentRecord(
            recordType: RecordType.placeReview,
            recordID: review.id.uuidString,
            ownerUserID: review.authorUserId,
            scopes: Set(Scope.allCases)
        )
    }

    func deleteDishReview(_ review: DishReview) async {
        await deleteContentRecord(
            recordType: RecordType.dishReview,
            recordID: review.id.uuidString,
            ownerUserID: review.authorUserId,
            scopes: Set(Scope.allCases)
        )
    }

    func deletePhotoAsset(_ asset: PhotoAsset) async {
        await deleteContentRecord(
            recordType: RecordType.photoAsset,
            recordID: asset.id.uuidString,
            ownerUserID: asset.ownerUserId,
            scopes: Set(Scope.allCases)
        )
    }

    func deleteActivity(_ item: ActivityItem, ownerUserID: UUID) async {
        await deleteContentRecord(
            recordType: RecordType.activityItem,
            recordID: item.id.uuidString,
            ownerUserID: ownerUserID,
            scopes: Set(Scope.allCases)
        )
    }

    func deletePlaceCategoryAssignment(_ assignment: PlaceCategoryAssignment) async {
        await deleteContentRecord(
            recordType: RecordType.placeCategoryAssignment,
            recordID: assignment.id.uuidString,
            ownerUserID: assignment.assignedByUserId,
            scopes: Set(Scope.allCases)
        )
    }

    func deleteCustomCategory(_ category: CustomCategory) async {
        await deleteContentRecord(
            recordType: RecordType.customCategory,
            recordID: category.id.uuidString,
            ownerUserID: category.ownerUserId,
            scopes: Set(Scope.allCases)
        )
    }

    private func backfillLocalContent(for viewer: User) async {
        do {
            for place in try context.fetch(FetchDescriptor<Place>()).filter({ $0.createdByUserId == viewer.id }) {
                await syncPlace(place)
            }

            for category in try context.fetch(FetchDescriptor<CustomCategory>()).filter({ $0.ownerUserId == viewer.id }) {
                await syncCustomCategory(category)
            }

            for assignment in try context.fetch(FetchDescriptor<PlaceCategoryAssignment>()).filter({ $0.assignedByUserId == viewer.id }) {
                await syncPlaceCategoryAssignment(assignment)
            }

            for review in try context.fetch(FetchDescriptor<PlaceReview>()).filter({ $0.authorUserId == viewer.id }) {
                await syncPlaceReview(review)
            }

            for review in try context.fetch(FetchDescriptor<DishReview>()).filter({ $0.authorUserId == viewer.id }) {
                await syncDishReview(review)
            }

            for asset in try context.fetch(FetchDescriptor<PhotoAsset>()).filter({ $0.ownerUserId == viewer.id }) {
                await syncPhotoAsset(asset, fileURL: photoStorageService.fileURL(for: asset.assetReference))
            }

            for item in try context.fetch(FetchDescriptor<ActivityItem>()).filter({ $0.actorUserId == viewer.id }) {
                await syncActivity(item)
            }
        } catch {
            logger.error("Unable to backfill local content: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func reconcileShareParticipants(for owner: User, friends: [User]) async throws {
        let share = try await ensureSharedContentShare(for: owner)
        let ownerRecordName = owner.cloudKitUserRecordName
        let desiredFriendRecordNames = Set(
            friends.compactMap(\.cloudKitUserRecordName).filter { $0 != ownerRecordName }
        )
        var existingParticipantsByRecordName: [String: CKShare.Participant] = [:]
        for participant in share.participants {
            if let recordName = participant.userIdentity.userRecordID?.recordName {
                existingParticipantsByRecordName[recordName] = participant
            }
        }

        var didMutate = false

        for recordName in desiredFriendRecordNames where existingParticipantsByRecordName[recordName] == nil {
            let participant = try await fetchParticipant(for: CKRecord.ID(recordName: recordName))
            participant.permission = .readOnly
            share.addParticipant(participant)
            didMutate = true
        }

        for (recordName, participant) in existingParticipantsByRecordName {
            guard participant.role == .privateUser else {
                continue
            }

            guard recordName != ownerRecordName, !desiredFriendRecordNames.contains(recordName) else {
                continue
            }

            share.removeParticipant(participant)
            didMutate = true
        }

        guard didMutate, let privateDatabase else {
            return
        }

        _ = try await saveRecord(in: privateDatabase, record: share)
    }

    private func acceptFriendSharesIfNeeded(_ friends: [User]) async {
        for friend in friends {
            guard let shareURLString = friend.sharedContentShareURL,
                  let shareURL = URL(string: shareURLString) else {
                continue
            }

            if acceptedShareURLs.contains(shareURLString) {
                continue
            }

            if let lastFailure = shareAcceptanceFailureTimestampsByURL[shareURLString],
               Date().timeIntervalSince(lastFailure) < shareAcceptanceFailureCooldown {
                continue
            }

            do {
                let metadata = try await fetchShareMetadata(for: shareURL)
                try await accept(metadata: metadata)
                acceptedShareURLs.insert(shareURLString)
                shareAcceptanceFailureTimestampsByURL[shareURLString] = nil
            } catch {
                if Self.isAlreadyAcceptedShareError(error) {
                    acceptedShareURLs.insert(shareURLString)
                    shareAcceptanceFailureTimestampsByURL[shareURLString] = nil
                    continue
                }

                shareAcceptanceFailureTimestampsByURL[shareURLString] = .now
                logger.debug("Skipping share acceptance for \(friend.id.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func mergeSharedContent(from friends: [User]) async throws {
        guard let sharedDatabase else {
            return
        }

        let friendIDs = Set(friends.map(\.id))
        guard !friendIDs.isEmpty else {
            return
        }

        let friendIDStrings = friendIDs.map(\.uuidString)
        let placeReviews = try await fetchPlaceReviews(authoredBy: friendIDStrings, in: sharedDatabase)
        let dishReviews = try await fetchDishReviews(authoredBy: friendIDStrings, in: sharedDatabase)
        let activities = try await fetchActivities(actorIDs: friendIDStrings, in: sharedDatabase)
        let categories = try await fetchCategories(ownerIDs: friendIDStrings, in: sharedDatabase)
        let assignments = try await fetchAssignments(assignedBy: friendIDStrings, in: sharedDatabase)
        let places = try await fetchPlaces(createdBy: friendIDStrings, in: sharedDatabase)
        let photoRecords = try await fetchPhotoAssets(ownerIDs: friendIDStrings, in: sharedDatabase)

        try mergePlaces(places)
        try mergeCategories(categories)
        try mergeAssignments(assignments)
        try mergePlaceReviews(placeReviews)
        try mergeDishReviews(dishReviews)
        try mergeActivities(activities)
        try mergePhotoAssets(photoRecords)
        try saveChanges(message: "Unable to update the shared content cache.")
    }

    private func mergePlaces(_ remotePlaces: [Place]) throws {
        let existingPlaces = try existingModelsByID(Place.self, id: \.id)

        for remotePlace in remotePlaces {
            if let existingPlace = existingPlaces[remotePlace.id] {
                existingPlace.appleMapsPlaceId = remotePlace.appleMapsPlaceId
                existingPlace.name = remotePlace.name
                existingPlace.latitude = remotePlace.latitude
                existingPlace.longitude = remotePlace.longitude
                existingPlace.address = remotePlace.address
                existingPlace.sourceType = remotePlace.sourceType
                existingPlace.createdByUserId = remotePlace.createdByUserId
                existingPlace.createdAt = remotePlace.createdAt
            } else {
                context.insert(
                    Place(
                        id: remotePlace.id,
                        appleMapsPlaceId: remotePlace.appleMapsPlaceId,
                        name: remotePlace.name,
                        latitude: remotePlace.latitude,
                        longitude: remotePlace.longitude,
                        address: remotePlace.address,
                        sourceType: remotePlace.sourceType,
                        createdByUserId: remotePlace.createdByUserId,
                        createdAt: remotePlace.createdAt
                    )
                )
            }
        }
    }

    private func mergeCategories(_ remoteCategories: [CustomCategory]) throws {
        let existingCategories = try existingModelsByID(CustomCategory.self, id: \.id)

        for remoteCategory in remoteCategories {
            if let existingCategory = existingCategories[remoteCategory.id] {
                existingCategory.ownerUserId = remoteCategory.ownerUserId
                existingCategory.name = remoteCategory.name
                existingCategory.iconName = remoteCategory.iconName
                existingCategory.createdAt = remoteCategory.createdAt
            } else {
                context.insert(
                    CustomCategory(
                        id: remoteCategory.id,
                        ownerUserId: remoteCategory.ownerUserId,
                        name: remoteCategory.name,
                        iconName: remoteCategory.iconName,
                        createdAt: remoteCategory.createdAt
                    )
                )
            }
        }
    }

    private func mergeAssignments(_ remoteAssignments: [PlaceCategoryAssignment]) throws {
        let existingAssignments = try existingModelsByID(PlaceCategoryAssignment.self, id: \.id)

        for remoteAssignment in remoteAssignments {
            if let existingAssignment = existingAssignments[remoteAssignment.id] {
                existingAssignment.placeId = remoteAssignment.placeId
                existingAssignment.categoryId = remoteAssignment.categoryId
                existingAssignment.assignedByUserId = remoteAssignment.assignedByUserId
            } else {
                context.insert(
                    PlaceCategoryAssignment(
                        id: remoteAssignment.id,
                        placeId: remoteAssignment.placeId,
                        categoryId: remoteAssignment.categoryId,
                        assignedByUserId: remoteAssignment.assignedByUserId
                    )
                )
            }
        }
    }

    private func mergePlaceReviews(_ remoteReviews: [PlaceReview]) throws {
        let existingReviews = try existingModelsByID(PlaceReview.self, id: \.id)

        for remoteReview in remoteReviews {
            if let existingReview = existingReviews[remoteReview.id] {
                existingReview.placeId = remoteReview.placeId
                existingReview.authorUserId = remoteReview.authorUserId
                existingReview.ratingOverall = remoteReview.ratingOverall
                existingReview.reviewText = remoteReview.reviewText
                existingReview.descriptionText = remoteReview.descriptionText
                existingReview.visibility = remoteReview.visibility
                existingReview.createdAt = remoteReview.createdAt
                existingReview.updatedAt = remoteReview.updatedAt
            } else {
                context.insert(
                    PlaceReview(
                        id: remoteReview.id,
                        placeId: remoteReview.placeId,
                        authorUserId: remoteReview.authorUserId,
                        ratingOverall: remoteReview.ratingOverall,
                        reviewText: remoteReview.reviewText,
                        descriptionText: remoteReview.descriptionText,
                        visibility: remoteReview.visibility,
                        createdAt: remoteReview.createdAt,
                        updatedAt: remoteReview.updatedAt
                    )
                )
            }
        }
    }

    private func mergeDishReviews(_ remoteReviews: [DishReview]) throws {
        let existingReviews = try existingModelsByID(DishReview.self, id: \.id)

        for remoteReview in remoteReviews {
            if let existingReview = existingReviews[remoteReview.id] {
                existingReview.placeId = remoteReview.placeId
                existingReview.authorUserId = remoteReview.authorUserId
                existingReview.placeReviewId = remoteReview.placeReviewId
                existingReview.visibility = remoteReview.visibility
                existingReview.dishName = remoteReview.dishName
                existingReview.dishRating = remoteReview.dishRating
                existingReview.dishReviewText = remoteReview.dishReviewText
                existingReview.price = remoteReview.price
                existingReview.createdAt = remoteReview.createdAt
                existingReview.updatedAt = remoteReview.updatedAt
            } else {
                context.insert(
                    DishReview(
                        id: remoteReview.id,
                        placeId: remoteReview.placeId,
                        authorUserId: remoteReview.authorUserId,
                        placeReviewId: remoteReview.placeReviewId,
                        visibility: remoteReview.visibility,
                        dishName: remoteReview.dishName,
                        dishRating: remoteReview.dishRating,
                        dishReviewText: remoteReview.dishReviewText,
                        price: remoteReview.price,
                        createdAt: remoteReview.createdAt,
                        updatedAt: remoteReview.updatedAt
                    )
                )
            }
        }
    }

    private func mergeActivities(_ remoteActivities: [ActivityItem]) throws {
        let existingActivities = try existingModelsByID(ActivityItem.self, id: \.id)

        for remoteActivity in remoteActivities {
            if let existingActivity = existingActivities[remoteActivity.id] {
                existingActivity.actorUserId = remoteActivity.actorUserId
                existingActivity.type = remoteActivity.type
                existingActivity.referenceId = remoteActivity.referenceId
                existingActivity.createdAt = remoteActivity.createdAt
            } else {
                context.insert(
                    ActivityItem(
                        id: remoteActivity.id,
                        actorUserId: remoteActivity.actorUserId,
                        type: remoteActivity.type,
                        referenceId: remoteActivity.referenceId,
                        createdAt: remoteActivity.createdAt
                    )
                )
            }
        }
    }

    private func mergePhotoAssets(_ remoteAssets: [RemotePhotoRecord]) throws {
        let existingAssets = try existingModelsByID(PhotoAsset.self, id: \.id)

        for remoteAsset in remoteAssets {
            let localReference: String
            if let binaryAssetURL = remoteAsset.binaryAssetURL,
               let data = try? Data(contentsOf: binaryAssetURL) {
                if let existingAsset = existingAssets[remoteAsset.id] {
                    photoStorageService.deleteImageIfPresent(for: existingAsset.assetReference)
                }
                localReference = try photoStorageService.storeImageData(data)
            } else if let existingAsset = existingAssets[remoteAsset.id] {
                localReference = existingAsset.assetReference
            } else {
                continue
            }

            if let existingAsset = existingAssets[remoteAsset.id] {
                existingAsset.ownerUserId = remoteAsset.ownerUserId
                existingAsset.placeId = remoteAsset.placeId
                existingAsset.placeReviewId = remoteAsset.placeReviewId
                existingAsset.dishReviewId = remoteAsset.dishReviewId
                existingAsset.assetReference = localReference
                existingAsset.createdAt = remoteAsset.createdAt
            } else {
                context.insert(
                    PhotoAsset(
                        id: remoteAsset.id,
                        ownerUserId: remoteAsset.ownerUserId,
                        placeId: remoteAsset.placeId,
                        placeReviewId: remoteAsset.placeReviewId,
                        dishReviewId: remoteAsset.dishReviewId,
                        assetReference: localReference,
                        createdAt: remoteAsset.createdAt
                    )
                )
            }
        }
    }

    private func purgeStaleSharedCache(viewerID: UUID, friendIDs: Set<UUID>) throws {
        for review in try context.fetch(FetchDescriptor<PlaceReview>()) where review.authorUserId != viewerID && !friendIDs.contains(review.authorUserId) {
            context.delete(review)
        }

        for review in try context.fetch(FetchDescriptor<DishReview>()) where review.authorUserId != viewerID && !friendIDs.contains(review.authorUserId) {
            context.delete(review)
        }

        for item in try context.fetch(FetchDescriptor<ActivityItem>()) where item.actorUserId != viewerID && !friendIDs.contains(item.actorUserId) {
            context.delete(item)
        }

        for category in try context.fetch(FetchDescriptor<CustomCategory>()) where category.ownerUserId != viewerID && !friendIDs.contains(category.ownerUserId) {
            context.delete(category)
        }

        for assignment in try context.fetch(FetchDescriptor<PlaceCategoryAssignment>()) where assignment.assignedByUserId != viewerID && !friendIDs.contains(assignment.assignedByUserId) {
            context.delete(assignment)
        }

        for asset in try context.fetch(FetchDescriptor<PhotoAsset>()) where asset.ownerUserId != viewerID && !friendIDs.contains(asset.ownerUserId) {
            photoStorageService.deleteImageIfPresent(for: asset.assetReference)
            context.delete(asset)
        }

        let remainingPlaceIDs = Set(
            try context.fetch(FetchDescriptor<PlaceReview>()).map(\.placeId)
                + context.fetch(FetchDescriptor<DishReview>()).map(\.placeId)
                + context.fetch(FetchDescriptor<PlaceCategoryAssignment>()).map(\.placeId)
                + context.fetch(FetchDescriptor<PhotoAsset>()).compactMap(\.placeId)
        )

        for place in try context.fetch(FetchDescriptor<Place>()) {
            guard let ownerUserID = place.createdByUserId,
                  ownerUserID != viewerID,
                  !friendIDs.contains(ownerUserID),
                  !remainingPlaceIDs.contains(place.id) else {
                continue
            }

            context.delete(place)
        }

        try saveChanges(message: "Unable to clean up the shared content cache.")
    }

    private func fetchPlaceReviews(authoredBy authorIDs: [String], in database: CKDatabase) async throws -> [PlaceReview] {
        try await fetchRecords(
            recordType: RecordType.placeReview,
            predicate: NSPredicate(format: "%K IN %@", FieldKey.authorUserId, authorIDs),
            sortDescriptors: [NSSortDescriptor(key: FieldKey.updatedAt, ascending: false)],
            in: database
        )
        .compactMap(placeReview(from:))
    }

    private func fetchDishReviews(authoredBy authorIDs: [String], in database: CKDatabase) async throws -> [DishReview] {
        try await fetchRecords(
            recordType: RecordType.dishReview,
            predicate: NSPredicate(format: "%K IN %@", FieldKey.authorUserId, authorIDs),
            sortDescriptors: [NSSortDescriptor(key: FieldKey.updatedAt, ascending: false)],
            in: database
        )
        .compactMap(dishReview(from:))
    }

    private func fetchActivities(actorIDs: [String], in database: CKDatabase) async throws -> [ActivityItem] {
        try await fetchRecords(
            recordType: RecordType.activityItem,
            predicate: NSPredicate(format: "%K IN %@", FieldKey.actorUserId, actorIDs),
            sortDescriptors: [NSSortDescriptor(key: FieldKey.createdAt, ascending: false)],
            in: database
        )
        .compactMap(activity(from:))
    }

    private func fetchCategories(ownerIDs: [String], in database: CKDatabase) async throws -> [CustomCategory] {
        try await fetchRecords(
            recordType: RecordType.customCategory,
            predicate: NSPredicate(format: "%K IN %@", FieldKey.ownerUserId, ownerIDs),
            sortDescriptors: [NSSortDescriptor(key: FieldKey.name, ascending: true)],
            in: database
        )
        .compactMap(category(from:))
    }

    private func fetchAssignments(assignedBy userIDs: [String], in database: CKDatabase) async throws -> [PlaceCategoryAssignment] {
        try await fetchRecords(
            recordType: RecordType.placeCategoryAssignment,
            predicate: NSPredicate(format: "%K IN %@", FieldKey.assignedByUserId, userIDs),
            in: database
        )
        .compactMap(assignment(from:))
    }

    private func fetchPlaces(createdBy userIDs: [String], in database: CKDatabase) async throws -> [Place] {
        try await fetchRecords(
            recordType: RecordType.place,
            predicate: NSPredicate(format: "%K IN %@", FieldKey.createdByUserId, userIDs),
            sortDescriptors: [NSSortDescriptor(key: FieldKey.createdAt, ascending: false)],
            in: database
        )
        .compactMap(place(from:))
    }

    private func fetchPhotoAssets(ownerIDs: [String], in database: CKDatabase) async throws -> [RemotePhotoRecord] {
        try await fetchRecords(
            recordType: RecordType.photoAsset,
            predicate: NSPredicate(format: "%K IN %@", FieldKey.ownerUserId, ownerIDs),
            sortDescriptors: [NSSortDescriptor(key: FieldKey.createdAt, ascending: false)],
            in: database
        )
        .compactMap(photoAsset(from:))
    }

    private func fetchRecords(
        recordType: String,
        predicate: NSPredicate,
        sortDescriptors: [NSSortDescriptor] = [],
        in database: CKDatabase
    ) async throws -> [CKRecord] {
        let query = CKQuery(recordType: recordType, predicate: predicate)
        query.sortDescriptors = sortDescriptors

        do {
            return try await performQuery(in: database, query: query)
        } catch {
            if isMissingSchemaError(error, recordType: recordType) {
                return []
            }
            throw error
        }
    }

    private func existingModelsByID<Model: PersistentModel>(
        _ modelType: Model.Type,
        id: KeyPath<Model, UUID>
    ) throws -> [UUID: Model] {
        var modelsByID: [UUID: Model] = [:]

        for model in try context.fetch(FetchDescriptor<Model>()) {
            let modelID = model[keyPath: id]
            if modelsByID[modelID] == nil {
                modelsByID[modelID] = model
            } else {
                context.delete(model)
            }
        }

        return modelsByID
    }

    private func place(from record: CKRecord) -> Place? {
        guard let name = record[FieldKey.name] as? String,
              let latitude = record[FieldKey.latitude] as? Double,
              let longitude = record[FieldKey.longitude] as? Double,
              let address = record[FieldKey.address] as? String,
              let sourceTypeRawValue = record[FieldKey.sourceType] as? String,
              let sourceType = PlaceSourceType(rawValue: sourceTypeRawValue),
              let createdAt = record[FieldKey.createdAt] as? Date else {
            return nil
        }

        return Place(
            id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
            appleMapsPlaceId: record[FieldKey.appleMapsPlaceId] as? String,
            name: name,
            latitude: latitude,
            longitude: longitude,
            address: address,
            sourceType: sourceType,
            createdByUserId: (record[FieldKey.createdByUserId] as? String).flatMap(UUID.init(uuidString:)),
            createdAt: createdAt
        )
    }

    private func category(from record: CKRecord) -> CustomCategory? {
        guard let ownerUserIdValue = record[FieldKey.ownerUserId] as? String,
              let ownerUserId = UUID(uuidString: ownerUserIdValue),
              let name = record[FieldKey.name] as? String,
              let createdAt = record[FieldKey.createdAt] as? Date else {
            return nil
        }

        return CustomCategory(
            id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
            ownerUserId: ownerUserId,
            name: name,
            iconName: record[FieldKey.iconName] as? String,
            createdAt: createdAt
        )
    }

    private func assignment(from record: CKRecord) -> PlaceCategoryAssignment? {
        guard let placeIdValue = record[FieldKey.placeId] as? String,
              let placeId = UUID(uuidString: placeIdValue),
              let categoryIdValue = record[FieldKey.categoryId] as? String,
              let categoryId = UUID(uuidString: categoryIdValue),
              let assignedByValue = record[FieldKey.assignedByUserId] as? String,
              let assignedByUserId = UUID(uuidString: assignedByValue) else {
            return nil
        }

        return PlaceCategoryAssignment(
            id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
            placeId: placeId,
            categoryId: categoryId,
            assignedByUserId: assignedByUserId
        )
    }

    private func placeReview(from record: CKRecord) -> PlaceReview? {
        guard let placeIdValue = record[FieldKey.placeId] as? String,
              let placeId = UUID(uuidString: placeIdValue),
              let authorUserIdValue = record[FieldKey.authorUserId] as? String,
              let authorUserId = UUID(uuidString: authorUserIdValue),
              let ratingOverall = record[FieldKey.ratingOverall] as? Int,
              let reviewText = record[FieldKey.reviewText] as? String,
              let descriptionText = record[FieldKey.descriptionText] as? String,
              let visibilityValue = record[FieldKey.visibility] as? String,
              let visibility = VisibilityStatus(rawValue: visibilityValue),
              let createdAt = record[FieldKey.createdAt] as? Date,
              let updatedAt = record[FieldKey.updatedAt] as? Date else {
            return nil
        }

        return PlaceReview(
            id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
            placeId: placeId,
            authorUserId: authorUserId,
            ratingOverall: ratingOverall,
            reviewText: reviewText,
            descriptionText: descriptionText,
            visibility: visibility,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private func dishReview(from record: CKRecord) -> DishReview? {
        guard let placeIdValue = record[FieldKey.placeId] as? String,
              let placeId = UUID(uuidString: placeIdValue),
              let authorUserIdValue = record[FieldKey.authorUserId] as? String,
              let authorUserId = UUID(uuidString: authorUserIdValue),
              let dishName = record[FieldKey.dishName] as? String,
              let dishRating = record[FieldKey.dishRating] as? Int,
              let dishReviewText = record[FieldKey.dishReviewText] as? String,
              let createdAt = record[FieldKey.createdAt] as? Date,
              let updatedAt = record[FieldKey.updatedAt] as? Date else {
            return nil
        }

        let visibility = (record[FieldKey.visibility] as? String).flatMap(VisibilityStatus.init(rawValue:)) ?? .friendsOnly

        return DishReview(
            id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
            placeId: placeId,
            authorUserId: authorUserId,
            placeReviewId: (record[FieldKey.placeReviewId] as? String).flatMap(UUID.init(uuidString:)),
            visibility: visibility,
            dishName: dishName,
            dishRating: dishRating,
            dishReviewText: dishReviewText,
            price: record[FieldKey.price] as? Double,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private func activity(from record: CKRecord) -> ActivityItem? {
        guard let actorUserIdValue = record[FieldKey.actorUserId] as? String,
              let actorUserId = UUID(uuidString: actorUserIdValue),
              let typeRawValue = record[FieldKey.type] as? String,
              let type = ActivityItemType(rawValue: typeRawValue),
              let referenceId = record[FieldKey.referenceId] as? String,
              let createdAt = record[FieldKey.createdAt] as? Date else {
            return nil
        }

        return ActivityItem(
            id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
            actorUserId: actorUserId,
            type: type,
            referenceId: referenceId,
            createdAt: createdAt
        )
    }

    private func photoAsset(from record: CKRecord) -> RemotePhotoRecord? {
        guard let ownerUserIdValue = record[FieldKey.ownerUserId] as? String,
              let ownerUserId = UUID(uuidString: ownerUserIdValue),
              let createdAt = record[FieldKey.createdAt] as? Date else {
            return nil
        }

        return RemotePhotoRecord(
            id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
            ownerUserId: ownerUserId,
            placeId: (record[FieldKey.placeId] as? String).flatMap(UUID.init(uuidString:)),
            placeReviewId: (record[FieldKey.placeReviewId] as? String).flatMap(UUID.init(uuidString:)),
            dishReviewId: (record["dishReviewId"] as? String).flatMap(UUID.init(uuidString:)),
            createdAt: createdAt,
            binaryAssetURL: (record[FieldKey.binaryAsset] as? CKAsset)?.fileURL
        )
    }

    private func upsertContentRecord(
        recordType: String,
        recordID: String,
        ownerUserID: UUID,
        scopes: Set<Scope>,
        configure: (CKRecord) -> Void
    ) async {
        for scope in scopes {
            do {
                guard let database = database(for: scope) else {
                    continue
                }

                let zoneID = try await zoneID(for: ownerUserID, scope: scope)
                let cloudRecordID = CKRecord.ID(recordName: recordID, zoneID: zoneID)
                let record = try await fetchOrCreateRecord(in: database, type: recordType, recordID: cloudRecordID)
                configure(record)
                _ = try await saveRecord(in: database, record: record)
            } catch {
                logger.error("Unable to sync \(recordType, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func deleteContentRecord(
        recordType: String,
        recordID: String,
        ownerUserID: UUID,
        scopes: Set<Scope>
    ) async {
        for scope in scopes {
            do {
                guard let database = database(for: scope) else {
                    continue
                }

                let zoneID = try await zoneID(for: ownerUserID, scope: scope)
                let cloudRecordID = CKRecord.ID(recordName: recordID, zoneID: zoneID)
                try await deleteRecord(in: database, with: cloudRecordID)
            } catch {
                logger.debug("Unable to delete \(recordType, privacy: .public) from \(String(describing: scope), privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func database(for scope: Scope) -> CKDatabase? {
        switch scope {
        case .privateOnly, .shared:
            return privateDatabase
        }
    }

    private func scope(for visibility: VisibilityStatus) -> Scope {
        switch visibility {
        case .friendsOnly:
            return .shared
        case .onlyMe:
            return .privateOnly
        }
    }

    private func oppositeScope(of scope: Scope) -> Scope {
        switch scope {
        case .privateOnly:
            return .shared
        case .shared:
            return .privateOnly
        }
    }

    private func visibility(for asset: PhotoAsset) -> VisibilityStatus {
        if let placeReviewId = asset.placeReviewId,
           let review = try? context.fetch(FetchDescriptor<PlaceReview>()).first(where: { $0.id == placeReviewId }) {
            return review.visibility
        }

        if let dishReviewId = asset.dishReviewId,
           let review = try? context.fetch(FetchDescriptor<DishReview>()).first(where: { $0.id == dishReviewId }) {
            return review.visibility
        }

        return .onlyMe
    }

    private func visibility(for item: ActivityItem) -> VisibilityStatus {
        guard let referenceUUID = UUID(uuidString: item.referenceId) else {
            return .onlyMe
        }

        if let review = try? context.fetch(FetchDescriptor<PlaceReview>()).first(where: { $0.id == referenceUUID }) {
            return review.visibility
        }

        if let review = try? context.fetch(FetchDescriptor<DishReview>()).first(where: { $0.id == referenceUUID }) {
            return review.visibility
        }

        return .onlyMe
    }

    private func activityOwnerUserID(for item: ActivityItem) -> UUID? {
        if item.actorUserId != UUID() {
            return item.actorUserId
        }

        guard let referenceUUID = UUID(uuidString: item.referenceId) else {
            return nil
        }

        if let review = try? context.fetch(FetchDescriptor<PlaceReview>()).first(where: { $0.id == referenceUUID }) {
            return review.authorUserId
        }

        if let review = try? context.fetch(FetchDescriptor<DishReview>()).first(where: { $0.id == referenceUUID }) {
            return review.authorUserId
        }

        return nil
    }

    private func zoneID(for ownerUserID: UUID, scope: Scope) async throws -> CKRecordZone.ID {
        switch scope {
        case .privateOnly:
            return CKRecordZone.default().zoneID
        case .shared:
            let zoneID = CKRecordZone.ID(zoneName: "shared-content-\(ownerUserID.uuidString)", ownerName: CKCurrentUserDefaultName)
            try await ensureRecordZoneExists(zoneID: zoneID)
            return zoneID
        }
    }

    private func ensureSharedContentShare(for user: User) async throws -> CKShare {
        guard let privateDatabase else {
            throw AppError.validationFailure("CloudKit is currently unavailable.")
        }

        let zoneID = try await zoneID(for: user.id, scope: .shared)

        if let existingShare = try await fetchSharedContentShare(
            in: privateDatabase,
            zoneID: zoneID,
            preferredRecordName: user.sharedContentShareRecordName
        ) {
            return existingShare
        }

        user.sharedContentShareRecordName = nil
        user.sharedContentShareURL = nil

        let share = CKShare(recordZoneID: zoneID)
        share.publicPermission = .none
        share[CKShare.SystemFieldKey.title] = "\(user.displayName)'s TrustMap" as CKRecordValue
        let savedRecord = try await saveRecord(in: privateDatabase, record: share)
        guard let savedShare = savedRecord as? CKShare else {
            throw AppError.validationFailure("CloudKit returned an unexpected share record.")
        }

        if savedShare.url != nil {
            return savedShare
        }

        return try await fetchSharedContentShare(
            in: privateDatabase,
            zoneID: zoneID,
            preferredRecordName: savedShare.recordID.recordName
        ) ?? savedShare
    }

    private func fetchSharedContentShare(
        in database: CKDatabase,
        zoneID: CKRecordZone.ID,
        preferredRecordName: String?
    ) async throws -> CKShare? {
        var candidateRecordNames: [String] = []

        if let preferredRecordName, !preferredRecordName.isEmpty {
            candidateRecordNames.append(preferredRecordName)
        }

        if !candidateRecordNames.contains(CKRecordNameZoneWideShare) {
            candidateRecordNames.append(CKRecordNameZoneWideShare)
        }

        for recordName in candidateRecordNames {
            let recordID = CKRecord.ID(recordName: recordName, zoneID: zoneID)
            if let share = try await fetchRecord(in: database, with: recordID) as? CKShare {
                return share
            }
        }

        return nil
    }

    private func ensureRecordZoneExists(zoneID: CKRecordZone.ID) async throws {
        guard let privateDatabase else {
            return
        }

        let zone = CKRecordZone(zoneID: zoneID)
        try await withCheckedThrowingContinuation { continuation in
            let operation = CKModifyRecordZonesOperation(recordZonesToSave: [zone], recordZoneIDsToDelete: nil)
            operation.modifyRecordZonesResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    if let ckError = error as? CKError,
                       ckError.code == .serverRejectedRequest || ckError.code == .zoneBusy {
                        continuation.resume(throwing: error)
                        return
                    }

                    if let ckError = error as? CKError,
                       ckError.code == .partialFailure {
                        continuation.resume()
                        return
                    }

                    continuation.resume()
                }
            }
            privateDatabase.add(operation)
        }
    }

    private func fetchCurrentUserRecordID() async throws -> CKRecord.ID? {
        try await withCheckedThrowingContinuation { continuation in
            container.fetchUserRecordID { recordID, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: recordID)
                }
            }
        }
    }

    private func fetchParticipant(for userRecordID: CKRecord.ID) async throws -> CKShare.Participant {
        try await withCheckedThrowingContinuation { continuation in
            let lookupInfo = CKUserIdentity.LookupInfo(userRecordID: userRecordID)
            let operation = CKFetchShareParticipantsOperation(userIdentityLookupInfos: [lookupInfo])
            var participant: CKShare.Participant?
            var participantError: Error?

            operation.perShareParticipantResultBlock = { _, result in
                switch result {
                case .success(let fetchedParticipant):
                    participant = fetchedParticipant
                case .failure(let error):
                    participantError = error
                }
            }

            operation.fetchShareParticipantsResultBlock = { result in
                switch result {
                case .success:
                    if let participant {
                        continuation.resume(returning: participant)
                    } else if let participantError {
                        continuation.resume(throwing: participantError)
                    } else {
                        continuation.resume(throwing: AppError.validationFailure("Unable to resolve the CloudKit participant."))
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            container.add(operation)
        }
    }

    private func fetchShareMetadata(for shareURL: URL) async throws -> CKShare.Metadata {
        try await withCheckedThrowingContinuation { continuation in
            let operation = CKFetchShareMetadataOperation(shareURLs: [shareURL])
            var fetchedMetadata: CKShare.Metadata?
            var metadataError: Error?

            operation.perShareMetadataResultBlock = { _, result in
                switch result {
                case .success(let metadata):
                    fetchedMetadata = metadata
                case .failure(let error):
                    metadataError = error
                }
            }

            operation.fetchShareMetadataResultBlock = { result in
                switch result {
                case .success:
                    if let fetchedMetadata {
                        continuation.resume(returning: fetchedMetadata)
                    } else if let metadataError {
                        continuation.resume(throwing: metadataError)
                    } else {
                        continuation.resume(throwing: AppError.validationFailure("Unable to fetch share metadata."))
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            container.add(operation)
        }
    }

    private func accept(metadata: CKShare.Metadata) async throws {
        try await withCheckedThrowingContinuation { continuation in
            let operation = CKAcceptSharesOperation(shareMetadatas: [metadata])
            operation.acceptSharesResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            container.add(operation)
        }
    }

    private func fetchOrCreateRecord(in database: CKDatabase, type: String, recordID: CKRecord.ID) async throws -> CKRecord {
        if let existingRecord = try await fetchRecord(in: database, with: recordID) {
            return existingRecord
        }

        return CKRecord(recordType: type, recordID: recordID)
    }

    private func fetchRecord(in database: CKDatabase, with recordID: CKRecord.ID) async throws -> CKRecord? {
        try await withCheckedThrowingContinuation { continuation in
            database.fetch(withRecordID: recordID) { record, error in
                if let error, Self.isRecordNotFoundError(error) {
                    continuation.resume(returning: nil)
                    return
                }

                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: record)
                }
            }
        }
    }

    private func saveRecord(in database: CKDatabase, record: CKRecord) async throws -> CKRecord {
        try await withCheckedThrowingContinuation { continuation in
            let operation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
            operation.savePolicy = .changedKeys
            operation.isAtomic = true

            var savedRecord: CKRecord?

            operation.perRecordSaveBlock = { _, result in
                if case .success(let record) = result {
                    savedRecord = record
                }
            }

            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    if let savedRecord {
                        continuation.resume(returning: savedRecord)
                    } else {
                        database.fetch(withRecordID: record.recordID) { fetchedRecord, error in
                            if let error, Self.isRecordNotFoundError(error) {
                                continuation.resume(returning: record)
                            } else if let error {
                                continuation.resume(throwing: error)
                            } else if let fetchedRecord {
                                continuation.resume(returning: fetchedRecord)
                            } else {
                                continuation.resume(returning: record)
                            }
                        }
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            database.add(operation)
        }
    }

    private func deleteRecord(in database: CKDatabase, with recordID: CKRecord.ID) async throws {
        try await withCheckedThrowingContinuation { continuation in
            database.delete(withRecordID: recordID) { _, error in
                if let error, Self.isRecordNotFoundError(error) {
                    continuation.resume()
                    return
                }

                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func performQuery(in database: CKDatabase, query: CKQuery) async throws -> [CKRecord] {
        try await withCheckedThrowingContinuation { continuation in
            var fetchedRecords: [CKRecord] = []
            let operation = CKQueryOperation(query: query)
            operation.recordMatchedBlock = { _, result in
                if case .success(let record) = result {
                    fetchedRecords.append(record)
                }
            }
            operation.queryResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: fetchedRecords)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            database.add(operation)
        }
    }

    private func isMissingSchemaError(_ error: Error, recordType: String) -> Bool {
        let description = (error as NSError).localizedDescription.lowercased()
        return description.contains("did not find record type") && description.contains(recordType.lowercased())
    }

    private nonisolated static func isRecordNotFoundError(_ error: Error) -> Bool {
        if let ckError = error as? CKError, ckError.code == .unknownItem {
            return true
        }

        let nsError = error as NSError
        let messages = [
            nsError.localizedDescription,
            nsError.localizedFailureReason,
            nsError.localizedRecoverySuggestion
        ]
        .compactMap { $0?.lowercased() }

        return messages.contains { message in
            message.contains("record not found") || message.contains("unknown item")
        }
    }

    private nonisolated static func isAlreadyAcceptedShareError(_ error: Error) -> Bool {
        let nsError = error as NSError
        let messages = [
            nsError.localizedDescription,
            nsError.localizedFailureReason,
            nsError.localizedRecoverySuggestion
        ]
        .compactMap { $0?.lowercased() }

        return messages.contains { message in
            (message.contains("already") && message.contains("accepted"))
                || (message.contains("accepted") && message.contains("share"))
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
