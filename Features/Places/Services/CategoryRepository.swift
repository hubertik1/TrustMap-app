import Foundation
import SwiftData

@MainActor
final class CategoryRepository {
    private static let defaultRestaurantCategoryName = "Restaurants"

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

    func defaultRestaurantCategory(for ownerUserID: UUID) throws -> CustomCategory {
        if let existingCategory = try categories(for: ownerUserID).first(where: {
            $0.name.caseInsensitiveCompare(Self.defaultRestaurantCategoryName) == .orderedSame
        }) {
            return existingCategory
        }

        return try createCategory(ownerUserID: ownerUserID, name: Self.defaultRestaurantCategoryName, iconName: "fork.knife")
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
        let assignments = try assignments(forPlace: placeID, assignedBy: userID)
        let staleAssignments = assignments.filter { $0.categoryId != categoryID }
        let existingAssignment = assignments.first { $0.categoryId == categoryID }

        if staleAssignments.isEmpty, existingAssignment != nil {
            return
        }

        for assignment in staleAssignments {
            context.delete(assignment)
        }

        let assignmentToKeep: PlaceCategoryAssignment
        let shouldSyncAssignment: Bool

        if let existingAssignment {
            assignmentToKeep = existingAssignment
            shouldSyncAssignment = false
        } else {
            let assignment = PlaceCategoryAssignment(
                placeId: placeID,
                categoryId: categoryID,
                assignedByUserId: userID
            )
            context.insert(assignment)
            assignmentToKeep = assignment
            shouldSyncAssignment = true
        }

        try saveChanges(message: "Unable to assign the category to this place.")

        if shouldSyncAssignment {
            Task { await cloudKitSyncService.syncPlaceCategoryAssignment(assignmentToKeep) }
        }
    }

    func removeAssignments(for placeID: UUID, assignedBy userID: UUID) throws {
        let assignments = try assignments(forPlace: placeID, assignedBy: userID)
        guard !assignments.isEmpty else {
            return
        }

        for assignment in assignments {
            context.delete(assignment)
        }

        try saveChanges(message: "Unable to clear the category for this place.")
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

    private func assignments(forPlace placeID: UUID, assignedBy userID: UUID) throws -> [PlaceCategoryAssignment] {
        try context.fetch(FetchDescriptor<PlaceCategoryAssignment>())
            .filter { $0.placeId == placeID && $0.assignedByUserId == userID }
    }
}
