import Foundation
import SwiftData

@MainActor
final class CategoryRepository {
    private static let defaultRestaurantCategoryName = "Restaurants"
    private static let hiddenCategoryIDsKeyPrefix = "hiddenCategoryIDs"

    private let persistenceController: PersistenceController
    private let cloudKitSyncService: CloudKitSyncing
    private let defaults: UserDefaults

    init(
        persistenceController: PersistenceController,
        cloudKitSyncService: CloudKitSyncing,
        defaults: UserDefaults = .standard
    ) {
        self.persistenceController = persistenceController
        self.cloudKitSyncService = cloudKitSyncService
        self.defaults = defaults
    }

    private var context: ModelContext {
        persistenceController.mainContext
    }

    func categories(for ownerUserID: UUID, includeHidden: Bool = false) throws -> [CustomCategory] {
        let descriptor = FetchDescriptor<CustomCategory>(sortBy: [SortDescriptor(\.name)])
        let hiddenIDs = hiddenCategoryIDs(for: ownerUserID)
        let filteredCategories = try context.fetch(descriptor).filter {
            $0.ownerUserId == ownerUserID && (includeHidden || !hiddenIDs.contains($0.id))
        }
        return sortCategories(filteredCategories)
    }

    func categories(createdBy ownerUserIDs: Set<UUID>, includeHidden: Bool = false) throws -> [CustomCategory] {
        guard !ownerUserIDs.isEmpty else {
            return []
        }

        let descriptor = FetchDescriptor<CustomCategory>(sortBy: [SortDescriptor(\.name)])
        let filteredCategories = try context.fetch(descriptor).filter {
            ownerUserIDs.contains($0.ownerUserId)
        }
        return sortCategories(filteredCategories)
    }

    func defaultRestaurantCategory(for ownerUserID: UUID) throws -> CustomCategory {
        if let existingCategory = try categories(for: ownerUserID, includeHidden: true).first(where: {
            $0.name.caseInsensitiveCompare(Self.defaultRestaurantCategoryName) == .orderedSame
        }) {
            try setHidden(false, for: existingCategory.id, ownerUserID: ownerUserID)
            return existingCategory
        }

        return try createCategory(ownerUserID: ownerUserID, name: Self.defaultRestaurantCategoryName, iconName: "fork.knife")
    }

    func categories(forPlace placeID: UUID) throws -> [CustomCategory] {
        let assignments = try context.fetch(FetchDescriptor<PlaceCategoryAssignment>())
            .filter { $0.placeId == placeID }
        let categoryIDs = Set(assignments.map(\.categoryId))
        let categories = try context.fetch(FetchDescriptor<CustomCategory>(sortBy: [SortDescriptor(\.name)]))
        return sortCategories(categories.filter { categoryIDs.contains($0.id) })
    }

    func createCategory(ownerUserID: UUID, name: String, iconName: String? = nil) throws -> CustomCategory {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else {
            throw AppError.validationFailure("Enter a category name.")
        }

        if let existing = try categories(for: ownerUserID, includeHidden: true).first(where: {
            $0.name.caseInsensitiveCompare(normalizedName) == .orderedSame
        }) {
            try setHidden(false, for: existing.id, ownerUserID: ownerUserID)
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

    func importCategory(_ sourceCategory: CustomCategory, to ownerUserID: UUID) throws -> CustomCategory {
        guard sourceCategory.ownerUserId != ownerUserID else {
            return sourceCategory
        }

        return try createCategory(
            ownerUserID: ownerUserID,
            name: sourceCategory.name,
            iconName: sourceCategory.iconName
        )
    }

    func updateVisibility(for categoryID: UUID, ownerUserID: UUID, isHidden: Bool) throws {
        guard let category = try category(withID: categoryID),
              category.ownerUserId == ownerUserID else {
            throw AppError.validationFailure("You can only manage your own categories.")
        }

        guard !isDefaultCategory(category) else {
            throw AppError.validationFailure("The default Restaurants category can't be hidden.")
        }

        guard hiddenCategoryIDs(for: ownerUserID).contains(categoryID) != isHidden else {
            return
        }

        try setHidden(isHidden, for: categoryID, ownerUserID: ownerUserID)
    }

    func deleteCategory(_ categoryID: UUID, ownerUserID: UUID) throws {
        guard let category = try category(withID: categoryID),
              category.ownerUserId == ownerUserID else {
            throw AppError.validationFailure("You can only delete your own categories.")
        }

        guard !isDefaultCategory(category) else {
            throw AppError.validationFailure("The default Restaurants category can't be deleted.")
        }

        let relatedAssignments = try context.fetch(FetchDescriptor<PlaceCategoryAssignment>())
            .filter { $0.categoryId == category.id }

        for assignment in relatedAssignments {
            context.delete(assignment)
        }

        context.delete(category)
        try setHidden(false, for: category.id, ownerUserID: ownerUserID)
        try saveChanges(message: "Unable to delete the category.")
    }

    func categoryNames(forPlace placeID: UUID) throws -> [String] {
        let names = try categories(forPlace: placeID).map(\.name)
        var seenNames = Set<String>()

        return names.filter { name in
            seenNames.insert(name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)).inserted
        }
    }

    func category(withID categoryID: UUID) throws -> CustomCategory? {
        let descriptor = FetchDescriptor<CustomCategory>(sortBy: [SortDescriptor(\.name)])
        return try context.fetch(descriptor).first { $0.id == categoryID }
    }

    func hiddenCategories(for ownerUserID: UUID) throws -> [CustomCategory] {
        let hiddenIDs = hiddenCategoryIDs(for: ownerUserID)
        guard !hiddenIDs.isEmpty else {
            return []
        }

        return try categories(for: ownerUserID, includeHidden: true).filter { hiddenIDs.contains($0.id) }
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

    private func isDefaultCategory(_ category: CustomCategory) -> Bool {
        category.name.caseInsensitiveCompare(Self.defaultRestaurantCategoryName) == .orderedSame
    }

    private func sortCategories(_ categories: [CustomCategory]) -> [CustomCategory] {
        categories.sorted { lhs, rhs in
            let lhsIsDefault = isDefaultCategory(lhs)
            let rhsIsDefault = isDefaultCategory(rhs)

            if lhsIsDefault != rhsIsDefault {
                return lhsIsDefault
            }

            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    private func hiddenCategoryIDs(for ownerUserID: UUID) -> Set<UUID> {
        let key = hiddenCategoryIDsKey(for: ownerUserID)
        let rawIDs = defaults.stringArray(forKey: key) ?? []
        return Set(rawIDs.compactMap(UUID.init(uuidString:)))
    }

    private func setHidden(_ isHidden: Bool, for categoryID: UUID, ownerUserID: UUID) throws {
        var hiddenIDs = hiddenCategoryIDs(for: ownerUserID)

        if isHidden {
            hiddenIDs.insert(categoryID)
        } else {
            hiddenIDs.remove(categoryID)
        }

        defaults.set(hiddenIDs.map(\.uuidString).sorted(), forKey: hiddenCategoryIDsKey(for: ownerUserID))
    }

    private func hiddenCategoryIDsKey(for ownerUserID: UUID) -> String {
        "\(Self.hiddenCategoryIDsKeyPrefix).\(ownerUserID.uuidString)"
    }
}
