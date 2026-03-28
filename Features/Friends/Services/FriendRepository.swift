import Foundation
import Security
import SwiftData

@MainActor
protocol FriendsRepository: AnyObject {
    func fetchFriends(for userID: UUID) throws -> [Friendship]
    func fetchIncomingInvites(for userID: UUID) throws -> [FriendInvite]
    func fetchOutgoingInvites(for userID: UUID) throws -> [FriendInvite]
    func createInvite(from inviterUserID: UUID) throws -> FriendInvite
    func findInvite(by token: String) throws -> FriendInvite?
    func prepareInvite(token: String, for inviteeUserID: UUID) throws -> FriendInvite?
    func acceptInvite(token: String, by inviteeUserID: UUID) throws
    func declineInvite(token: String, by inviteeUserID: UUID) throws
    func revokeInvite(inviteID: UUID, by inviterUserID: UUID) throws
    func acceptedFriendIDs(for userID: UUID) throws -> Set<UUID>
    func acceptedFriends(for userID: UUID) throws -> [User]
    func areFriends(_ firstUserID: UUID, _ secondUserID: UUID) throws -> Bool
}

@MainActor
final class FriendRepository: FriendsRepository {
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

    func fetchFriends(for userID: UUID) throws -> [Friendship] {
        try expireElapsedInvitesIfNeeded()

        return try allFriendships()
            .filter { $0.userAId == userID || $0.userBId == userID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func acceptedFriendIDs(for userID: UUID) throws -> Set<UUID> {
        let friendships = try fetchFriends(for: userID)
        var ids = Set<UUID>()

        for friendship in friendships {
            if let otherUserID = friendship.otherUserID(for: userID) {
                ids.insert(otherUserID)
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

    func fetchIncomingInvites(for userID: UUID) throws -> [FriendInvite] {
        try expireElapsedInvitesIfNeeded()

        return try allInvites()
            .filter { $0.status == .pending && $0.inviteeUserId == userID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func fetchOutgoingInvites(for userID: UUID) throws -> [FriendInvite] {
        try expireElapsedInvitesIfNeeded()

        return try allInvites()
            .filter { $0.status == .pending && $0.inviterUserId == userID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func createInvite(from inviterUserID: UUID) throws -> FriendInvite {
        try expireElapsedInvitesIfNeeded()

        guard try userRepository.user(withID: inviterUserID) != nil else {
            throw AppError.missingCurrentUser
        }

        if let existingInvite = try allInvites().first(where: {
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
        context.insert(invite)
        try saveChanges()
        Task { await cloudKitSyncService.syncFriendInvite(invite) }
        return invite
    }

    func findInvite(by token: String) throws -> FriendInvite? {
        try expireElapsedInvitesIfNeeded()
        return try allInvites().first(where: { $0.token == token })
    }

    func prepareInvite(token: String, for inviteeUserID: UUID) throws -> FriendInvite? {
        guard let invite = try findInvite(by: token) else {
            return nil
        }

        guard invite.status == .pending, !invite.isExpired else {
            return invite
        }

        guard invite.inviterUserId != inviteeUserID else {
            return invite
        }

        if try areFriends(invite.inviterUserId, inviteeUserID) {
            return invite
        }

        if let claimedInviteeID = invite.inviteeUserId, claimedInviteeID != inviteeUserID {
            return invite
        }

        if invite.inviteeUserId == nil {
            invite.inviteeUserId = inviteeUserID
            try saveChanges()
            Task { await cloudKitSyncService.syncFriendInvite(invite) }
        }

        return invite
    }

    func acceptInvite(token: String, by inviteeUserID: UUID) throws {
        try expireElapsedInvitesIfNeeded()

        guard let invite = try findInvite(by: token) else {
            throw AppError.validationFailure("This invite could not be found.")
        }

        guard invite.status == .pending else {
            return
        }

        guard !invite.isExpired else {
            throw AppError.validationFailure("This invite has expired.")
        }

        guard invite.inviterUserId != inviteeUserID else {
            throw AppError.validationFailure("You can’t accept your own invite.")
        }

        if let claimedInviteeID = invite.inviteeUserId, claimedInviteeID != inviteeUserID {
            throw AppError.validationFailure("This invite is reserved for another person.")
        }

        if try areFriends(invite.inviterUserId, inviteeUserID) {
            return
        }

        invite.inviteeUserId = inviteeUserID
        invite.status = .accepted
        invite.respondedAt = .now

        let friendship = Friendship(
            userAId: invite.inviterUserId,
            userBId: inviteeUserID
        )
        context.insert(friendship)
        try saveChanges()
        Task {
            await cloudKitSyncService.syncFriendInvite(invite)
            await cloudKitSyncService.syncFriendship(friendship)
        }
    }

    func declineInvite(token: String, by inviteeUserID: UUID) throws {
        try expireElapsedInvitesIfNeeded()

        guard let invite = try findInvite(by: token) else {
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
        Task { await cloudKitSyncService.syncFriendInvite(invite) }
    }

    func revokeInvite(inviteID: UUID, by inviterUserID: UUID) throws {
        try expireElapsedInvitesIfNeeded()

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
        Task { await cloudKitSyncService.syncFriendInvite(invite) }
    }

    func areFriends(_ firstUserID: UUID, _ secondUserID: UUID) throws -> Bool {
        try friendshipBetween(firstUserID, secondUserID) != nil
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

    private func expireElapsedInvitesIfNeeded() throws {
        let now = Date.now
        let pendingExpiredInvites = try allInvites().filter {
            $0.status == .pending && ($0.expiresAt?.timeIntervalSince(now) ?? 1) < 0
        }

        guard !pendingExpiredInvites.isEmpty else {
            return
        }

        for invite in pendingExpiredInvites {
            invite.status = .expired
        }

        try saveChanges()
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
