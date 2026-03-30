import Foundation
import Security
import SwiftData

@MainActor
protocol FriendsRepository: AnyObject {
    func fetchFriends(for userID: UUID) async throws -> [Friendship]
    func fetchIncomingInvites(for userID: UUID) async throws -> [FriendInvite]
    func fetchOutgoingInvites(for userID: UUID) async throws -> [FriendInvite]
    func createInvite(from inviterUserID: UUID) async throws -> FriendInvite
    func findInvite(by token: String) async throws -> FriendInvite?
    func prepareInvite(token: String, for inviteeUserID: UUID) async throws -> FriendInvite?
    func acceptInvite(token: String, by inviteeUserID: UUID) async throws
    func declineInvite(token: String, by inviteeUserID: UUID) async throws
    func revokeInvite(inviteID: UUID, by inviterUserID: UUID) async throws
    func acceptedFriendIDs(for userID: UUID) async throws -> Set<UUID>
    func acceptedFriends(for userID: UUID) async throws -> [User]
    func areFriends(_ firstUserID: UUID, _ secondUserID: UUID) async throws -> Bool
}

@MainActor
final class FriendRepository: FriendsRepository {
    private let persistenceController: PersistenceController
    private let cloudKitSyncService: CloudKitSyncing
    private let socialGraphService: any SocialGraphCloudKitServicing
    private let userRepository: UserProfileRepository

    init(
        persistenceController: PersistenceController,
        cloudKitSyncService: CloudKitSyncing,
        socialGraphService: any SocialGraphCloudKitServicing,
        userRepository: UserProfileRepository
    ) {
        self.persistenceController = persistenceController
        self.cloudKitSyncService = cloudKitSyncService
        self.socialGraphService = socialGraphService
        self.userRepository = userRepository
    }

    private var context: ModelContext {
        persistenceController.mainContext
    }

    func fetchFriends(for userID: UUID) async throws -> [Friendship] {
        let friendships = try await socialGraphService.fetchFriendships(for: userID)
        let cachedFriendships = try cacheFriendships(friendships)
        let participantIDs = Set(cachedFriendships.flatMap { [$0.userAId, $0.userBId] })
        _ = try await userRepository.refreshUsers(withIDs: participantIDs)
        return cachedFriendships.sorted { $0.createdAt > $1.createdAt }
    }

    func acceptedFriendIDs(for userID: UUID) async throws -> Set<UUID> {
        let friendships = try await fetchFriends(for: userID)
        var ids = Set<UUID>()

        for friendship in friendships {
            if let otherUserID = friendship.otherUserID(for: userID) {
                ids.insert(otherUserID)
            }
        }

        return ids
    }

    func acceptedFriends(for userID: UUID) async throws -> [User] {
        let friendIDs = try await acceptedFriendIDs(for: userID)
        let cachedRemoteUsers = try await userRepository.refreshUsers(withIDs: friendIDs)
        var usersByID = Dictionary(uniqueKeysWithValues: cachedRemoteUsers.map { ($0.id, $0) })

        for localUser in try userRepository.allKnownUsers() {
            usersByID[localUser.id] = localUser
        }

        return friendIDs
            .compactMap { usersByID[$0] }
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    func fetchIncomingInvites(for userID: UUID) async throws -> [FriendInvite] {
        let remoteInvites = try await socialGraphService.fetchPendingIncomingInvites(for: userID)
        let invites = try await normalizeInvites(remoteInvites)
        let participantIDs = Set(invites.compactMap(\.inviterUserId) + invites.compactMap(\.inviteeUserId))
        _ = try await userRepository.refreshUsers(withIDs: participantIDs)
        return invites
            .filter { $0.status == .pending && $0.inviteeUserId == userID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func fetchOutgoingInvites(for userID: UUID) async throws -> [FriendInvite] {
        let remoteInvites = try await socialGraphService.fetchPendingOutgoingInvites(for: userID)
        let invites = try await normalizeInvites(remoteInvites)
        let participantIDs = Set(invites.compactMap(\.inviterUserId) + invites.compactMap(\.inviteeUserId))
        _ = try await userRepository.refreshUsers(withIDs: participantIDs)
        return invites
            .filter { $0.status == .pending && $0.inviterUserId == userID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func createInvite(from inviterUserID: UUID) async throws -> FriendInvite {
        guard try userRepository.user(withID: inviterUserID) != nil else {
            throw AppError.missingCurrentUser
        }

        let existingInvites = try await socialGraphService.fetchPendingOutgoingInvites(for: inviterUserID)
        let pendingExistingInvites = try await normalizeInvites(existingInvites)
        if let existingInvite = pendingExistingInvites.first(where: {
            $0.inviterUserId == inviterUserID
                && $0.status == .pending
                && $0.inviteeUserId == nil
                && !$0.isExpired
        }) {
            return existingInvite
        }

        let invite = FriendInvite(
            token: Self.generateToken(),
            inviterUserId: inviterUserID,
            expiresAt: .now.addingTimeInterval(AppConfiguration.friendInviteLifetime)
        )
        let cachedInvite = try cacheInvite(invite)
        try await socialGraphService.upsertInvite(cachedInvite)
        Task { await cloudKitSyncService.syncFriendInvite(cachedInvite) }
        return cachedInvite
    }

    func findInvite(by token: String) async throws -> FriendInvite? {
        if let remoteInvite = try await socialGraphService.fetchInvite(token: token) {
            let cachedInvite = try await normalizeInvite(remoteInvite)
            let participantIDs = Set([cachedInvite.inviterUserId] + [cachedInvite.inviteeUserId].compactMap { $0 })
            _ = try await userRepository.refreshUsers(withIDs: participantIDs)
            return cachedInvite
        }

        return try allInvites().first(where: { $0.token == token })
    }

    func prepareInvite(token: String, for inviteeUserID: UUID) async throws -> FriendInvite? {
        guard let invite = try await findInvite(by: token) else {
            return nil
        }

        guard invite.status == .pending, !invite.isExpired else {
            return invite
        }

        guard invite.inviterUserId != inviteeUserID else {
            return invite
        }

        if try await areFriends(invite.inviterUserId, inviteeUserID) {
            return invite
        }

        if let claimedInviteeID = invite.inviteeUserId, claimedInviteeID != inviteeUserID {
            return invite
        }

        if invite.inviteeUserId == nil {
            invite.inviteeUserId = inviteeUserID
            try saveChanges()
            try await socialGraphService.upsertInvite(invite)
            Task { await cloudKitSyncService.syncFriendInvite(invite) }
        }

        return invite
    }

    func acceptInvite(token: String, by inviteeUserID: UUID) async throws {
        guard let invite = try await findInvite(by: token) else {
            throw AppError.validationFailure("This invite could not be found.")
        }

        guard invite.status == .pending else {
            return
        }

        guard !invite.isExpired else {
            invite.status = .expired
            try saveChanges()
            try await socialGraphService.upsertInvite(invite)
            throw AppError.validationFailure("This invite has expired.")
        }

        guard invite.inviterUserId != inviteeUserID else {
            throw AppError.validationFailure("You can’t accept your own invite.")
        }

        if let claimedInviteeID = invite.inviteeUserId, claimedInviteeID != inviteeUserID {
            throw AppError.validationFailure("This invite is reserved for another person.")
        }

        let existingFriendship = try await socialGraphService.fetchFriendship(
            firstUserID: invite.inviterUserId,
            secondUserID: inviteeUserID
        )

        invite.inviteeUserId = inviteeUserID
        invite.status = .accepted
        invite.respondedAt = .now

        let friendship = existingFriendship
            ?? Friendship(
                id: StableIdentifier.friendshipID(firstUserID: invite.inviterUserId, secondUserID: inviteeUserID),
                userAId: invite.inviterUserId,
                userBId: inviteeUserID
            )

        _ = try cacheFriendship(friendship)
        try saveChanges()
        try await socialGraphService.upsertInvite(invite)
        try await socialGraphService.upsertFriendship(friendship)

        Task {
            await cloudKitSyncService.syncFriendInvite(invite)
            await cloudKitSyncService.syncFriendship(friendship)
        }
    }

    func declineInvite(token: String, by inviteeUserID: UUID) async throws {
        guard let invite = try await findInvite(by: token) else {
            throw AppError.validationFailure("This invite could not be found.")
        }

        guard invite.status == .pending else {
            return
        }

        guard invite.inviterUserId != inviteeUserID else {
            throw AppError.validationFailure("You can’t decline your own invite.")
        }

        if let claimedInviteeID = invite.inviteeUserId, claimedInviteeID != inviteeUserID {
            throw AppError.validationFailure("This invite is reserved for another person.")
        }

        invite.inviteeUserId = inviteeUserID
        invite.status = .declined
        invite.respondedAt = .now
        try saveChanges()
        try await socialGraphService.upsertInvite(invite)
        Task { await cloudKitSyncService.syncFriendInvite(invite) }
    }

    func revokeInvite(inviteID: UUID, by inviterUserID: UUID) async throws {
        guard let invite = try invite(withID: inviteID) else {
            return
        }

        guard invite.inviterUserId == inviterUserID else {
            throw AppError.validationFailure("Only the sender can cancel this invite.")
        }

        guard invite.status == .pending else {
            return
        }

        invite.status = .revoked
        invite.respondedAt = .now
        try saveChanges()
        try await socialGraphService.upsertInvite(invite)
        Task { await cloudKitSyncService.syncFriendInvite(invite) }
    }

    func areFriends(_ firstUserID: UUID, _ secondUserID: UUID) async throws -> Bool {
        if let remoteFriendship = try await socialGraphService.fetchFriendship(firstUserID: firstUserID, secondUserID: secondUserID) {
            _ = try cacheFriendship(remoteFriendship)
            return true
        }

        return try friendshipBetween(firstUserID, secondUserID) != nil
    }

    private func invite(withID inviteID: UUID) throws -> FriendInvite? {
        try allInvites().first(where: { $0.id == inviteID })
    }

    private func friendshipBetween(_ firstUserID: UUID, _ secondUserID: UUID) throws -> Friendship? {
        let orderedPair = Self.orderedPair(firstUserID, secondUserID)

        return try allFriendships().first {
            $0.userAId == orderedPair.0 && $0.userBId == orderedPair.1
        }
    }

    private func allInvites() throws -> [FriendInvite] {
        let descriptor = FetchDescriptor<FriendInvite>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return try context.fetch(descriptor)
    }

    private func allFriendships() throws -> [Friendship] {
        let descriptor = FetchDescriptor<Friendship>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return try context.fetch(descriptor)
    }

    private func normalizeInvites(_ invites: [FriendInvite]) async throws -> [FriendInvite] {
        var normalizedInvites: [FriendInvite] = []
        normalizedInvites.reserveCapacity(invites.count)

        for invite in invites {
            normalizedInvites.append(try await normalizeInvite(invite))
        }

        return normalizedInvites
    }

    private func normalizeInvite(_ invite: FriendInvite) async throws -> FriendInvite {
        let cachedInvite = try cacheInvite(invite)

        if cachedInvite.status == .pending, cachedInvite.isExpired {
            cachedInvite.status = .expired
            try saveChanges()
            try await socialGraphService.upsertInvite(cachedInvite)
            Task { await cloudKitSyncService.syncFriendInvite(cachedInvite) }
        }

        return cachedInvite
    }

    @discardableResult
    private func cacheInvite(_ remoteInvite: FriendInvite) throws -> FriendInvite {
        if let existingInvite = try invite(withID: remoteInvite.id) {
            existingInvite.token = remoteInvite.token
            existingInvite.inviterUserId = remoteInvite.inviterUserId
            existingInvite.inviteeUserId = remoteInvite.inviteeUserId
            existingInvite.status = remoteInvite.status
            existingInvite.createdAt = remoteInvite.createdAt
            existingInvite.expiresAt = remoteInvite.expiresAt
            existingInvite.respondedAt = remoteInvite.respondedAt
            try saveChanges()
            return existingInvite
        }

        let invite = FriendInvite(
            id: remoteInvite.id,
            token: remoteInvite.token,
            inviterUserId: remoteInvite.inviterUserId,
            inviteeUserId: remoteInvite.inviteeUserId,
            status: remoteInvite.status,
            createdAt: remoteInvite.createdAt,
            expiresAt: remoteInvite.expiresAt,
            respondedAt: remoteInvite.respondedAt
        )
        context.insert(invite)
        try saveChanges()
        return invite
    }

    private func cacheFriendships(_ remoteFriendships: [Friendship]) throws -> [Friendship] {
        try remoteFriendships.map(cacheFriendship)
    }

    @discardableResult
    private func cacheFriendship(_ remoteFriendship: Friendship) throws -> Friendship {
        if let existingFriendship = try inviteCompatibleFriendship(withID: remoteFriendship.id) {
            existingFriendship.userAId = remoteFriendship.userAId
            existingFriendship.userBId = remoteFriendship.userBId
            existingFriendship.createdAt = remoteFriendship.createdAt
            try saveChanges()
            return existingFriendship
        }

        let friendship = Friendship(
            id: remoteFriendship.id,
            userAId: remoteFriendship.userAId,
            userBId: remoteFriendship.userBId,
            createdAt: remoteFriendship.createdAt
        )
        context.insert(friendship)
        try saveChanges()
        return friendship
    }

    private func inviteCompatibleFriendship(withID friendshipID: UUID) throws -> Friendship? {
        try allFriendships().first(where: { $0.id == friendshipID })
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

    private static func orderedPair(_ firstID: UUID, _ secondID: UUID) -> (UUID, UUID) {
        firstID.uuidString < secondID.uuidString ? (firstID, secondID) : (secondID, firstID)
    }

    private static func generateToken(byteCount: Int = 24) -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)

        guard status == errSecSuccess else {
            return UUID().uuidString.replacingOccurrences(of: "-", with: "")
        }

        return Data(bytes)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
