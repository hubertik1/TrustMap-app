import Foundation
import SwiftData

@MainActor
final class FriendRepository {
    private let persistenceController: PersistenceController
    private let cloudKitSyncService: CloudKitSyncing
    private let userRepository: UserProfileRepository

    init(
        persistenceController: PersistenceController,
        cloudKitSyncService: CloudKitSyncing,
        userRepository: UserProfileRepository
    ) {
        self.persistenceController = persistenceController
        self.cloudKitSyncService = cloudKitSyncService
        self.userRepository = userRepository
    }

    private var context: ModelContext {
        persistenceController.mainContext
    }

    func acceptedFriendIDs(for userID: UUID) throws -> Set<UUID> {
        let relations = try allRelations()
        var ids = Set<UUID>()

        for relation in relations where relation.status == .accepted {
            if relation.ownerUserId == userID {
                ids.insert(relation.targetUserId)
            }
            if relation.targetUserId == userID {
                ids.insert(relation.ownerUserId)
            }
        }

        return ids
    }

    func acceptedFriends(for userID: UUID) throws -> [User] {
        let friendIDs = try acceptedFriendIDs(for: userID)
        let users = try userRepository.allKnownUsers()
        return users
            .filter { friendIDs.contains($0.id) }
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    func incomingRequests(for userID: UUID) throws -> [FriendRelation] {
        try allRelations()
            .filter { $0.status == .pending && $0.targetUserId == userID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func outgoingRequests(for userID: UUID) throws -> [FriendRelation] {
        try allRelations()
            .filter { $0.status == .pending && $0.ownerUserId == userID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func sendRequest(from ownerUserID: UUID, to targetUserID: UUID) throws {
        guard ownerUserID != targetUserID else {
            throw AppError.validationFailure("You can’t send a friend request to yourself.")
        }

        if let existing = try relationBetween(ownerUserID, targetUserID) {
            if existing.status == .pending || existing.status == .accepted {
                return
            }

            existing.status = .pending
            try saveChanges()
            Task { await cloudKitSyncService.syncFriendRelation(existing) }
            return
        }

        let relation = FriendRelation(
            ownerUserId: ownerUserID,
            targetUserId: targetUserID,
            status: .pending
        )
        context.insert(relation)
        try saveChanges()
        Task { await cloudKitSyncService.syncFriendRelation(relation) }
    }

    func acceptRequest(_ relationID: UUID) throws {
        guard let relation = try relation(withID: relationID) else {
            return
        }

        relation.status = .accepted
        try saveChanges()
        Task { await cloudKitSyncService.syncFriendRelation(relation) }
    }

    func rejectRequest(_ relationID: UUID) throws {
        guard let relation = try relation(withID: relationID) else {
            return
        }

        relation.status = .rejected
        try saveChanges()
        Task { await cloudKitSyncService.syncFriendRelation(relation) }
    }

    func removeFriend(currentUserID: UUID, friendID: UUID) throws {
        guard let relation = try relationBetween(currentUserID, friendID) else {
            return
        }

        context.delete(relation)
        try saveChanges()
    }

    private func relation(withID relationID: UUID) throws -> FriendRelation? {
        try allRelations().first(where: { $0.id == relationID })
    }

    private func relationBetween(_ firstID: UUID, _ secondID: UUID) throws -> FriendRelation? {
        try allRelations().first {
            ($0.ownerUserId == firstID && $0.targetUserId == secondID)
                || ($0.ownerUserId == secondID && $0.targetUserId == firstID)
        }
    }

    private func allRelations() throws -> [FriendRelation] {
        let descriptor = FetchDescriptor<FriendRelation>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return try context.fetch(descriptor)
    }

    private func saveChanges() throws {
        do {
            if context.hasChanges {
                try context.save()
            }
        } catch {
            throw AppError.persistenceFailure("Unable to save the friend relationship.")
        }
    }
}
