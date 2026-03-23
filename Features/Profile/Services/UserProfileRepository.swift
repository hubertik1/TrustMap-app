import Foundation
import SwiftData

@MainActor
final class UserProfileRepository {
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

    func user(withID userID: UUID) throws -> User? {
        let descriptor = FetchDescriptor<User>(sortBy: [SortDescriptor(\.createdAt)])
        return try context.fetch(descriptor).first(where: { $0.id == userID })
    }

    func user(forAppleUserID appleUserID: String) throws -> User? {
        let descriptor = FetchDescriptor<User>(sortBy: [SortDescriptor(\.createdAt)])
        return try context.fetch(descriptor).first(where: { $0.appleUserId == appleUserID })
    }

    func allKnownUsers(excluding userID: UUID? = nil) throws -> [User] {
        let descriptor = FetchDescriptor<User>(sortBy: [SortDescriptor(\.displayName)])
        let users = try context.fetch(descriptor)

        guard let userID else {
            return users
        }

        return users.filter { $0.id != userID }
    }

    func searchUsers(query: String, excluding userID: UUID? = nil) throws -> [User] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let users = try allKnownUsers(excluding: userID)

        guard !normalizedQuery.isEmpty else {
            return Array(users.prefix(20))
        }

        return users.filter {
            $0.displayName.localizedCaseInsensitiveContains(normalizedQuery)
        }
    }

    func createOrUpdateSignedInUser(credential: AppleSignInCredential) throws -> User {
        if let existingUser = try user(forAppleUserID: credential.userID) {
            if let displayName = credential.displayName, !displayName.isEmpty {
                existingUser.displayName = displayName
            }

            try saveChanges()
            Task { await cloudKitSyncService.syncUser(existingUser) }
            return existingUser
        }

        let user = User(
            appleUserId: credential.userID,
            displayName: credential.displayName ?? "My TrustMap"
        )
        context.insert(user)
        try saveChanges()
        Task { await cloudKitSyncService.syncUser(user) }
        return user
    }

    func updateProfile(userID: UUID, displayName: String, bio: String?) throws {
        guard let user = try user(withID: userID) else {
            throw AppError.missingCurrentUser
        }

        user.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        user.bio = bio?.trimmingCharacters(in: .whitespacesAndNewlines)
        try saveChanges()
        Task { await cloudKitSyncService.syncUser(user) }
    }

    private func saveChanges() throws {
        do {
            if context.hasChanges {
                try context.save()
            }
        } catch {
            throw AppError.persistenceFailure("Unable to save the user profile.")
        }
    }
}
