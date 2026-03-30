import Foundation

@MainActor
final class FriendsViewModel: ObservableObject {
    struct FriendListItem: Identifiable {
        let id: UUID
        let displayName: String
        let bio: String?
        let addedAt: Date
    }

    struct IncomingInviteListItem: Identifiable {
        let id: UUID
        let token: String
        let inviterName: String
        let inviterBio: String?
        let createdAt: Date
    }

    struct OutgoingInviteListItem: Identifiable {
        let id: UUID
        let recipientName: String?
        let createdAt: Date
        let statusLabel: String
    }

    struct InviteSharePayload: Identifiable {
        let id = UUID()
        let message: String
        let url: URL

        var activityItems: [Any] {
            [url, message]
        }
    }

    @Published private(set) var friends: [FriendListItem] = []
    @Published private(set) var incomingInvites: [IncomingInviteListItem] = []
    @Published private(set) var outgoingInvites: [OutgoingInviteListItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var activeInviteID: UUID?
    @Published private(set) var isPreparingInvite = false
    @Published var sharePayload: InviteSharePayload?

    private let sessionStore: SessionStore
    private let userRepository: UserProfileRepository
    private let friendRepository: any FriendsRepository
    private let inviteLinkBuilder: any InviteLinkBuilding

    init(
        sessionStore: SessionStore,
        userRepository: UserProfileRepository,
        friendRepository: any FriendsRepository,
        inviteLinkBuilder: any InviteLinkBuilding
    ) {
        self.sessionStore = sessionStore
        self.userRepository = userRepository
        self.friendRepository = friendRepository
        self.inviteLinkBuilder = inviteLinkBuilder
    }

    func load() async {
        guard let currentUser = sessionStore.currentUser else {
            errorMessage = AppError.missingCurrentUser.errorDescription
            friends = []
            incomingInvites = []
            outgoingInvites = []
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let friendships = try await friendRepository.fetchFriends(for: currentUser.id)
            let incomingInvites = try await friendRepository.fetchIncomingInvites(for: currentUser.id)
            let outgoingInvites = try await friendRepository.fetchOutgoingInvites(for: currentUser.id)
            let knownUsers = try userRepository.allKnownUsers()
            let userLookup: [UUID: User] = knownUsers.reduce(into: [:]) { result, user in
                result[user.id] = user
            }

            friends = friendships.compactMap { friendship in
                guard let otherUserID = friendship.otherUserID(for: currentUser.id) else {
                    return nil
                }

                let user = userLookup[otherUserID]
                return FriendListItem(
                    id: friendship.id,
                    displayName: user?.displayName ?? "TrustMap User",
                    bio: user?.bio,
                    addedAt: friendship.createdAt
                )
            }

            self.incomingInvites = incomingInvites.map { invite in
                let inviter = userLookup[invite.inviterUserId]
                return IncomingInviteListItem(
                    id: invite.id,
                    token: invite.token,
                    inviterName: inviter?.displayName ?? "TrustMap User",
                    inviterBio: inviter?.bio,
                    createdAt: invite.createdAt
                )
            }

            self.outgoingInvites = outgoingInvites.map { invite in
                OutgoingInviteListItem(
                    id: invite.id,
                    recipientName: invite.inviteeUserId.flatMap { userLookup[$0]?.displayName },
                    createdAt: invite.createdAt,
                    statusLabel: invite.inviteeUserId == nil ? "Waiting for someone to open your link." : "Waiting for a response."
                )
            }
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
            friends = []
            incomingInvites = []
            outgoingInvites = []
        }

        isLoading = false
    }

    func addFriend() async {
        guard let currentUser = sessionStore.currentUser else {
            errorMessage = AppError.missingCurrentUser.errorDescription
            return
        }

        guard !isPreparingInvite else {
            return
        }

        isPreparingInvite = true
        errorMessage = nil
        defer { isPreparingInvite = false }

        do {
            let invite = try await friendRepository.createInvite(from: currentUser.id)
            let inviteURL = try inviteLinkBuilder.inviteURL(for: invite.token)
            await load()
            sharePayload = InviteSharePayload(
                message: "Join me in TrustMap and let’s add each other as friends.",
                url: inviteURL
            )
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
        }
    }

    func accept(_ invite: IncomingInviteListItem) async {
        await performInviteAction(inviteID: invite.id) { currentUserID in
            try await friendRepository.acceptInvite(token: invite.token, by: currentUserID)
        }
    }

    func decline(_ invite: IncomingInviteListItem) async {
        await performInviteAction(inviteID: invite.id) { currentUserID in
            try await friendRepository.declineInvite(token: invite.token, by: currentUserID)
        }
    }

    func revoke(_ invite: OutgoingInviteListItem) async {
        guard let currentUser = sessionStore.currentUser else {
            errorMessage = AppError.missingCurrentUser.errorDescription
            return
        }

        guard activeInviteID == nil else {
            return
        }

        activeInviteID = invite.id
        errorMessage = nil
        defer { activeInviteID = nil }

        do {
            try await friendRepository.revokeInvite(inviteID: invite.id, by: currentUser.id)
            await load()
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
        }
    }

    var hasAnyEntries: Bool {
        !friends.isEmpty || !incomingInvites.isEmpty
    }

    var isMutating: Bool {
        isPreparingInvite || activeInviteID != nil
    }

    private func performInviteAction(
        inviteID: UUID,
        _ action: (_ currentUserID: UUID) async throws -> Void
    ) async {
        guard let currentUser = sessionStore.currentUser else {
            errorMessage = AppError.missingCurrentUser.errorDescription
            return
        }

        guard activeInviteID == nil else {
            return
        }

        activeInviteID = inviteID
        errorMessage = nil
        defer { activeInviteID = nil }

        do {
            try await action(currentUser.id)
            await load()
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
        }
    }
}
