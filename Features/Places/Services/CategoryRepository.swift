import Foundation
import SwiftData

@MainActor
final class CategoryRepository {
    private let persistenceController: PersistenceController
    private let cloudKitSyncService: CloudKitSyncing

    init(
        persistenceController: PersistenceController,
        cloudKitSyncService: CloudKitSyncing
    ) {
        self.persistenceController = persistenceController
        self.cloudKitSyncService = cloudKitSyncService
    }

    private var context: ModelContext {
        persistenceController.mainContext
    }

    func categories(for ownerUserID: UUID) throws -> [CustomCategory] {
        let descriptor = FetchDescriptor<CustomCategory>(sortBy: [SortDescriptor(\.name)])
        return try context.fetch(descriptor).filter { $0.ownerUserId == ownerUserID }
    }

    func categories(forPlace placeID: UUID) throws -> [CustomCategory] {
        let assignments = try context.fetch(FetchDescriptor<PlaceCategoryAssignment>())
            .filter { $0.placeId == placeID }
        let categoryIDs = Set(assignments.map(\.categoryId))
        let categories = try context.fetch(FetchDescriptor<CustomCategory>(sortBy: [SortDescriptor(\.name)]))
        return categories.filter { categoryIDs.contains($0.id) }
    }

    func createCategory(ownerUserID: UUID, name: String, iconName: String? = nil) throws -> CustomCategory {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else {
            throw AppError.validationFailure("Enter a category name.")
        }

        if let existing = try categories(for: ownerUserID).first(where: { $0.name.caseInsensitiveCompare(normalizedName) == .orderedSame }) {
            return existing
        }

        let category = CustomCategory(
            ownerUserId: ownerUserID,
            name: normalizedName,
            iconName: iconName
        )
        context.insert(category)
        try saveChanges(message: "Unable to save the category.")
        Task { await cloudKitSyncService.syncCustomCategory(category) }
        return category
    }

    func assignCategory(_ categoryID: UUID, to placeID: UUID, assignedBy userID: UUID) throws {
        let assignments = try context.fetch(FetchDescriptor<PlaceCategoryAssignment>())
        if assignments.contains(where: { $0.placeId == placeID && $0.categoryId == categoryID }) {
            return
        }

        let assignment = PlaceCategoryAssignment(
            placeId: placeID,
            categoryId: categoryID,
            assignedByUserId: userID
        )
        context.insert(assignment)
        try saveChanges(message: "Unable to assign the category to this place.")
        Task { await cloudKitSyncService.syncPlaceCategoryAssignment(assignment) }
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
