import Foundation

@MainActor
final class DeepLinkRouter: ObservableObject {
    struct PresentedInvite: Identifiable, Equatable {
        let token: String

        var id: String { token }
    }

    @Published var presentedInvite: PresentedInvite?

    private let inviteLinkBuilder: any InviteLinkBuilding
    private let pendingDeepLinkStore: PendingDeepLinkStore

    init(
        inviteLinkBuilder: any InviteLinkBuilding,
        pendingDeepLinkStore: PendingDeepLinkStore
    ) {
        self.inviteLinkBuilder = inviteLinkBuilder
        self.pendingDeepLinkStore = pendingDeepLinkStore
    }

    func handleIncomingURL(_ url: URL, isAuthenticated: Bool) {
        guard let token = inviteLinkBuilder.inviteToken(from: url) else {
            return
        }

        if isAuthenticated {
            presentedInvite = PresentedInvite(token: token)
        } else {
            pendingDeepLinkStore.storeInviteToken(token)
        }
    }

    func resumePendingInviteIfNeeded(isAuthenticated: Bool) {
        guard isAuthenticated, let token = pendingDeepLinkStore.consumeInviteToken() else {
            return
        }

        presentedInvite = PresentedInvite(token: token)
    }

    func dismissPresentedInvite() {
        presentedInvite = nil
    }
}
