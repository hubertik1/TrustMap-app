import Foundation
import OSLog
import SwiftData

@MainActor
final class UserProfileRepository {
    private static let legacyFallbackDisplayName = "My TrustMap"
    private static let genericFallbackDisplayName = "Apple User"

    private let logger = Logger(subsystem: "TrustMap", category: "UserProfileRepository")
    private let persistenceController: PersistenceController
    private let cloudKitSyncService: CloudKitSyncService
    private let socialGraphService: any SocialGraphCloudKitServicing

    init(
        persistenceController: PersistenceController,
        cloudKitSyncService: CloudKitSyncService,
        socialGraphService: any SocialGraphCloudKitServicing
    ) {
        self.persistenceController = persistenceController
        self.cloudKitSyncService = cloudKitSyncService
        self.socialGraphService = socialGraphService
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
        var seenUserIDs = Set<UUID>()
        let users = try context.fetch(descriptor).filter { seenUserIDs.insert($0.id).inserted }

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

    func restoreAuthorizedUser(forAppleUserID appleUserID: String) async throws -> User? {
        let stableUserID = StableIdentifier.userID(forAppleUserID: appleUserID)
        _ = try migrateLocalUserIfNeeded(appleUserID: appleUserID, stableUserID: stableUserID)

        let remoteUser: User?
        do {
            remoteUser = try await socialGraphService.fetchUser(id: stableUserID)
        } catch {
            logger.error("Unable to fetch remote user during restore: \(error.localizedDescription, privacy: .public)")
            remoteUser = nil
        }

        if let remoteUser {
            if let cachedUser = try cacheRemoteUser(remoteUser) {
                await synchronizeRemoteStateIfPossible(for: cachedUser)
                return cachedUser
            }
            return nil
        }

        if let localUser = try user(withID: stableUserID) ?? user(forAppleUserID: appleUserID) {
            await synchronizeRemoteStateIfPossible(for: localUser)
            return localUser
        }

        return nil
    }

    func createOrUpdateSignedInUser(credential: AppleSignInCredential) async throws -> User {
        let stableUserID = StableIdentifier.userID(forAppleUserID: credential.userID)
        let resolvedDisplayName = Self.resolvedDisplayName(from: credential)

        let migratedLocalUser = try migrateLocalUserIfNeeded(
            appleUserID: credential.userID,
            stableUserID: stableUserID
        )

        let remoteUser: User?
        do {
            remoteUser = try await socialGraphService.fetchUser(id: stableUserID)
        } catch {
            logger.error("Unable to fetch remote user during sign in: \(error.localizedDescription, privacy: .public)")
            remoteUser = nil
        }
        let currentUser = try cacheRemoteUser(remoteUser)
            ?? migratedLocalUser
            ?? user(withID: stableUserID)
            ?? user(forAppleUserID: credential.userID)
            ?? {
                let user = User(
                    id: stableUserID,
                    appleUserId: credential.userID,
                    displayName: resolvedDisplayName ?? Self.genericFallbackDisplayName
                )
                context.insert(user)
                return user
            }()

        currentUser.id = stableUserID
        currentUser.appleUserId = credential.userID

        let normalizedCurrentDisplayName = currentUser.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let shouldUpdateDisplayName =
            normalizedCurrentDisplayName.isEmpty
            || normalizedCurrentDisplayName == Self.legacyFallbackDisplayName
            || normalizedCurrentDisplayName == Self.genericFallbackDisplayName
            || credential.displayName != nil

        if let resolvedDisplayName,
           !resolvedDisplayName.isEmpty,
           shouldUpdateDisplayName {
            currentUser.displayName = resolvedDisplayName
        }

        try saveChanges()
        await synchronizeRemoteStateIfPossible(for: currentUser)
        Task { await cloudKitSyncService.syncUser(currentUser) }
        return currentUser
    }

    func refreshUsers(withIDs ids: Set<UUID>) async throws -> [User] {
        let remoteUsers = try await socialGraphService.fetchUsers(ids: ids)
        return try cacheRemoteUsers(remoteUsers)
    }

    func refreshUser(withID userID: UUID) async throws -> User? {
        guard let remoteUser = try await socialGraphService.fetchUser(id: userID) else {
            return try user(withID: userID)
        }

        return try cacheRemoteUser(remoteUser)
    }

    func updateProfile(userID: UUID, displayName: String, bio: String?) throws {
        guard let user = try user(withID: userID) else {
            throw AppError.missingCurrentUser
        }

        user.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        user.bio = bio?.trimmingCharacters(in: .whitespacesAndNewlines)
        try saveChanges()
        Task {
            await synchronizeRemoteStateIfPossible(for: user)
            await cloudKitSyncService.syncUser(user)
        }
    }

    func synchronizeCurrentUserIfPossible(userID: UUID) async {
        guard let user = try? user(withID: userID) else {
            return
        }

        await synchronizeRemoteStateIfPossible(for: user)
        Task { await cloudKitSyncService.syncUser(user) }
    }

    private func synchronizeRemoteStateIfPossible(for user: User) async {
        do {
            try await cloudKitSyncService.prepareSharingProfile(for: user)
        } catch {
            logger.error("Unable to prepare CloudKit sharing profile: \(error.localizedDescription, privacy: .public)")
        }

        do {
            try await socialGraphService.upsertUser(user)
        } catch {
            logger.error("Unable to upsert public user profile: \(error.localizedDescription, privacy: .public)")
        }
    }

    @discardableResult
    func cacheRemoteUser(_ remoteUser: User?) throws -> User? {
        guard let remoteUser else {
            return nil
        }

        if let existingUser = try user(withID: remoteUser.id) {
            existingUser.appleUserId = remoteUser.appleUserId
            existingUser.displayName = remoteUser.displayName
            existingUser.bio = remoteUser.bio
            existingUser.avatarReference = remoteUser.avatarReference
            existingUser.cloudKitUserRecordName = remoteUser.cloudKitUserRecordName
            existingUser.sharedContentShareRecordName = remoteUser.sharedContentShareRecordName
            existingUser.sharedContentShareURL = remoteUser.sharedContentShareURL
            existingUser.createdAt = remoteUser.createdAt
            try saveChanges()
            return existingUser
        }

        if let existingByAppleUserID = try user(forAppleUserID: remoteUser.appleUserId) {
            if existingByAppleUserID.id != remoteUser.id {
                try migrateUserReferences(from: existingByAppleUserID.id, to: remoteUser.id)
            }

            existingByAppleUserID.id = remoteUser.id
            existingByAppleUserID.displayName = remoteUser.displayName
            existingByAppleUserID.bio = remoteUser.bio
            existingByAppleUserID.avatarReference = remoteUser.avatarReference
            existingByAppleUserID.cloudKitUserRecordName = remoteUser.cloudKitUserRecordName
            existingByAppleUserID.sharedContentShareRecordName = remoteUser.sharedContentShareRecordName
            existingByAppleUserID.sharedContentShareURL = remoteUser.sharedContentShareURL
            existingByAppleUserID.createdAt = remoteUser.createdAt
            try saveChanges()
            return existingByAppleUserID
        }

        let user = User(
            id: remoteUser.id,
            appleUserId: remoteUser.appleUserId,
            displayName: remoteUser.displayName,
            avatarReference: remoteUser.avatarReference,
            bio: remoteUser.bio,
            cloudKitUserRecordName: remoteUser.cloudKitUserRecordName,
            sharedContentShareRecordName: remoteUser.sharedContentShareRecordName,
            sharedContentShareURL: remoteUser.sharedContentShareURL,
            createdAt: remoteUser.createdAt
        )
        context.insert(user)
        try saveChanges()
        return user
    }

    func cacheRemoteUsers(_ remoteUsers: [User]) throws -> [User] {
        var cachedUsers: [User] = []
        cachedUsers.reserveCapacity(remoteUsers.count)

        for remoteUser in remoteUsers {
            if let cachedUser = try cacheRemoteUser(remoteUser) {
                cachedUsers.append(cachedUser)
            }
        }

        return cachedUsers
    }

    private func migrateLocalUserIfNeeded(appleUserID: String, stableUserID: UUID) throws -> User? {
        guard let existingUser = try user(forAppleUserID: appleUserID) else {
            return nil
        }

        guard existingUser.id != stableUserID else {
            return existingUser
        }

        try migrateUserReferences(from: existingUser.id, to: stableUserID)
        existingUser.id = stableUserID
        try saveChanges()
        return existingUser
    }

    private func migrateUserReferences(from oldUserID: UUID, to newUserID: UUID) throws {
        guard oldUserID != newUserID else {
            return
        }

        try reassign(\Place.createdByUserId, from: oldUserID, to: newUserID)
        try reassign(\CustomCategory.ownerUserId, from: oldUserID, to: newUserID)
        try reassign(\PlaceCategoryAssignment.assignedByUserId, from: oldUserID, to: newUserID)
        try reassign(\PlaceReview.authorUserId, from: oldUserID, to: newUserID)
        try reassign(\DishReview.authorUserId, from: oldUserID, to: newUserID)
        try reassign(\PhotoAsset.ownerUserId, from: oldUserID, to: newUserID)
        try reassign(\ActivityItem.actorUserId, from: oldUserID, to: newUserID)

        let friendshipDescriptor = FetchDescriptor<Friendship>()
        for friendship in try context.fetch(friendshipDescriptor) {
            if friendship.userAId == oldUserID {
                friendship.userAId = newUserID
            }
            if friendship.userBId == oldUserID {
                friendship.userBId = newUserID
            }
        }

        let inviteDescriptor = FetchDescriptor<FriendInvite>()
        for invite in try context.fetch(inviteDescriptor) {
            if invite.inviterUserId == oldUserID {
                invite.inviterUserId = newUserID
            }
            if invite.inviteeUserId == oldUserID {
                invite.inviteeUserId = newUserID
            }
        }

        try saveChanges()
    }

    private func reassign<Model: PersistentModel>(
        _ keyPath: ReferenceWritableKeyPath<Model, UUID>,
        from oldUserID: UUID,
        to newUserID: UUID
    ) throws {
        let descriptor = FetchDescriptor<Model>()
        for model in try context.fetch(descriptor) where model[keyPath: keyPath] == oldUserID {
            model[keyPath: keyPath] = newUserID
        }
    }

    private func reassign<Model: PersistentModel>(
        _ keyPath: ReferenceWritableKeyPath<Model, UUID?>,
        from oldUserID: UUID,
        to newUserID: UUID
    ) throws {
        let descriptor = FetchDescriptor<Model>()
        for model in try context.fetch(descriptor) where model[keyPath: keyPath] == oldUserID {
            model[keyPath: keyPath] = newUserID
        }
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

    private static func resolvedDisplayName(from credential: AppleSignInCredential) -> String? {
        if let displayName = credential.displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !displayName.isEmpty {
            return displayName
        }

        guard let email = credential.email?.trimmingCharacters(in: .whitespacesAndNewlines),
              !email.isEmpty,
              !email.contains("privaterelay.appleid.com") else {
            return nil
        }

        let localPart = email.split(separator: "@").first.map(String.init) ?? email
        let replaced = localPart.replacingOccurrences(
            of: "[._-]+",
            with: " ",
            options: .regularExpression
        )
        let collapsed = replaced.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !collapsed.isEmpty else {
            return nil
        }

        return collapsed.localizedCapitalized
    }
}
