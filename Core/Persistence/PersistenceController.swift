import Foundation
import OSLog
import SwiftData

@MainActor
final class PersistenceController {
    let modelContainer: ModelContainer
    private let logger = Logger(subsystem: "TrustMap", category: "Persistence")

    init(inMemory: Bool = false) {
        do {
            modelContainer = try Self.makeModelContainer(inMemory: inMemory)
        } catch {
            logger.error("Unable to open persistent SwiftData store. Falling back to in-memory store: \(error.localizedDescription, privacy: .public)")

            do {
                modelContainer = try Self.makeModelContainer(inMemory: true)
            } catch {
                fatalError("Failed to create SwiftData container: \(error.localizedDescription)")
            }
        }
    }

    var mainContext: ModelContext {
        modelContainer.mainContext
    }

    func resetAllData() {
        do {
            try deleteAll(User.self)
            try deleteAll(FriendInvite.self)
            try deleteAll(Friendship.self)
            try deleteAll(Place.self)
            try deleteAll(PlaceReview.self)
            try deleteAll(DishReview.self)
            try deleteAll(PhotoAsset.self)
            try deleteAll(CustomCategory.self)
            try deleteAll(PlaceCategoryAssignment.self)
            try deleteAll(ActivityItem.self)

            if mainContext.hasChanges {
                try mainContext.save()
            }
        } catch {
            logger.error("Unable to reset the local SwiftData cache: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func deleteAll<Model: PersistentModel>(_ modelType: Model.Type) throws {
        let descriptor = FetchDescriptor<Model>()
        for model in try mainContext.fetch(descriptor) {
            mainContext.delete(model)
        }
    }

    private static func makeModelContainer(inMemory: Bool) throws -> ModelContainer {
        let configuration: ModelConfiguration

        if inMemory {
            configuration = ModelConfiguration(
                "TrustMap",
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
        } else {
            let storeURL = try persistentStoreURL()
            configuration = ModelConfiguration(
                "TrustMap",
                url: storeURL,
                cloudKitDatabase: .none
            )
        }

        return try ModelContainer(
            for: User.self,
            FriendInvite.self,
            Friendship.self,
            Place.self,
            PlaceReview.self,
            DishReview.self,
            PhotoAsset.self,
            CustomCategory.self,
            PlaceCategoryAssignment.self,
            ActivityItem.self,
            configurations: configuration
        )
    }

    private static func persistentStoreURL() throws -> URL {
        let applicationSupportURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        try FileManager.default.createDirectory(
            at: applicationSupportURL,
            withIntermediateDirectories: true
        )
        return applicationSupportURL.appendingPathComponent("TrustMap.store")
    }
}
