import Foundation

@MainActor
final class PendingDeepLinkStore {
    private let defaults: UserDefaults
    private let inviteTokenKey = "trustmap.pendingInviteToken"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func storeInviteToken(_ token: String) {
        defaults.set(token, forKey: inviteTokenKey)
    }

    func peekInviteToken() -> String? {
        defaults.string(forKey: inviteTokenKey)
    }

    func consumeInviteToken() -> String? {
        let token = peekInviteToken()
        clearInviteToken()
        return token
    }

    func clearInviteToken() {
        defaults.removeObject(forKey: inviteTokenKey)
    }
}
