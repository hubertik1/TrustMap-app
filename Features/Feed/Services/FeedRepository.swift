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

    func feed(for viewerID: UUID, friendIDs: Set<UUID>) throws -> [ActivityItem] {
        let descriptor = FetchDescriptor<ActivityItem>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return try context.fetch(descriptor)
            .filter { $0.actorUserId != viewerID && friendIDs.contains($0.actorUserId) }
    }
}
