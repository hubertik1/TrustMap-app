import Foundation
import SwiftData

@MainActor
final class FeedRepository {
    private let persistenceController: PersistenceController

    init(persistenceController: PersistenceController) {
        self.persistenceController = persistenceController
    }

    private var context: ModelContext {
        persistenceController.mainContext
    }

    func placeFeed(actorIDs: Set<UUID>) throws -> [ActivityItem] {
        let descriptor = FetchDescriptor<ActivityItem>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        var seenActivityIDs = Set<UUID>()
        return try context.fetch(descriptor)
            .filter { seenActivityIDs.insert($0.id).inserted }
            .filter {
                actorIDs.contains($0.actorUserId)
                    && ($0.type == .placeReviewAdded || $0.type == .dishReviewAdded)
            }
    }
}
