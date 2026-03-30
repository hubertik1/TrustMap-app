import Foundation

@MainActor
final class AcceptInviteViewModel: ObservableObject {
    struct InviteContext {
        let inviterName: String
        let inviterBio: String?
        let createdAt: Date
    }

    enum State {
        case loading
        case valid(InviteContext)
        case alreadyAccepted(InviteContext)
        case alreadyFriends(InviteContext)
        case expired(InviteContext)
        case invalid
        case ownInvite(InviteContext)
        case declined(InviteContext)
        case revoked(InviteContext)
        case genericError(String)
    }

    @Published private(set) var state: State = .loading
    @Published private(set) var isPerformingAction = false

    let token: String

    private let sessionStore: SessionStore
    private let userRepository: UserProfileRepository
    private let friendRepository: any FriendsRepository

    init(
        token: String,
        sessionStore: SessionStore,
        userRepository: UserProfileRepository,
        friendRepository: any FriendsRepository
    ) {
        self.token = token
        self.sessionStore = sessionStore
        self.userRepository = userRepository
        self.friendRepository = friendRepository
    }

    func load() async {
        guard let currentUser = sessionStore.currentUser else {
            state = .genericError("Sign in to respond to this invite.")
            return
        }

        state = .loading

        do {
            guard let invite = try await friendRepository.prepareInvite(token: token, for: currentUser.id) else {
                state = .invalid
                return
            }

            let inviter: User? =
                if invite.inviterUserId == currentUser.id {
                    currentUser
                } else {
                    try await userRepository.refreshUser(withID: invite.inviterUserId)
                        ?? userRepository.user(withID: invite.inviterUserId)
                }

            guard let inviter else {
                state = .invalid
                return
            }

            let context = InviteContext(
                inviterName: inviter.displayName,
                inviterBio: inviter.bio,
                createdAt: invite.createdAt
            )
            let resolvedState = try await resolveState(invite: invite, context: context, currentUserID: currentUser.id)

            switch resolvedState {
            case .valid:
                await autoAcceptInvite(currentUserID: currentUser.id, context: context)

            default:
                state = resolvedState
            }
        } catch {
            state = .genericError(AppError.wrap(error).errorDescription ?? "Something went wrong.")
        }
    }

    func accept() async {
        await performAction {
            guard let currentUser = sessionStore.currentUser else {
                throw AppError.missingCurrentUser
            }

            try await friendRepository.acceptInvite(token: token, by: currentUser.id)
        }
    }

    func decline() async {
        await performAction {
            guard let currentUser = sessionStore.currentUser else {
                throw AppError.missingCurrentUser
            }

            try await friendRepository.declineInvite(token: token, by: currentUser.id)
        }
    }

    private func resolveState(
        invite: FriendInvite,
        context: InviteContext,
        currentUserID: UUID
    ) async throws -> State {
        if invite.isExpired {
            return .expired(context)
        }

        switch invite.status {
        case .accepted:
            return .alreadyAccepted(context)
        case .declined:
            return .declined(context)
        case .revoked:
            return .revoked(context)
        case .expired:
            return .expired(context)
        case .pending:
            break
        }

        if invite.inviterUserId == currentUserID {
            return .ownInvite(context)
        }

        if let claimedInviteeID = invite.inviteeUserId, claimedInviteeID != currentUserID {
            return .genericError("This invite is already reserved for someone else.")
        }

        if try await friendRepository.areFriends(invite.inviterUserId, currentUserID) {
            return .alreadyFriends(context)
        }

        return .valid(context)
    }

    private func performAction(_ action: () async throws -> Void) async {
        guard !isPerformingAction else {
            return
        }

        isPerformingAction = true
        defer { isPerformingAction = false }

        do {
            try await action()
            await load()
        } catch {
            state = .genericError(AppError.wrap(error).errorDescription ?? "Something went wrong.")
        }
    }

    private func autoAcceptInvite(currentUserID: UUID, context: InviteContext) async {
        guard !isPerformingAction else {
            return
        }

        isPerformingAction = true
        defer { isPerformingAction = false }

        do {
            try await friendRepository.acceptInvite(token: token, by: currentUserID)

            if let acceptedInvite = try await friendRepository.findInvite(by: token) {
                state = try await resolveState(
                    invite: acceptedInvite,
                    context: context,
                    currentUserID: currentUserID
                )
            } else {
                state = .alreadyAccepted(context)
            }
        } catch {
            state = .genericError(AppError.wrap(error).errorDescription ?? "Something went wrong.")
        }
    }
}
