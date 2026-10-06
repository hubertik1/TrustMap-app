import AuthenticationServices
import Foundation

@MainActor
final class SessionStore: ObservableObject, APISessionProviding {
    enum State {
        case launching
        case signedOut
        case signedIn(User)
    }

    @Published private(set) var state: State = .launching
    @Published var alertMessage: String?
    var onWillSignOut: (() async -> Void)?
    var onDidClearSession: (() -> Void)?

    private let authService: AuthServicing
    private let authRepository: AuthRepository
    private let refreshCenter: AppRefreshCenter
    private let userRepository: UserProfileRepository
    private let tokenStore: KeychainTokenStore

    private var storedTokens: SessionTokens?
    private var refreshTask: Task<AuthSession, Error>?

    init(
        authService: AuthServicing,
        authRepository: AuthRepository,
        refreshCenter: AppRefreshCenter,
        userRepository: UserProfileRepository,
        tokenStore: KeychainTokenStore
    ) {
        self.authService = authService
        self.authRepository = authRepository
        self.refreshCenter = refreshCenter
        self.userRepository = userRepository
        self.tokenStore = tokenStore
    }

    var currentUser: User? {
        guard case .signedIn(let user) = state else {
            return nil
        }

        return user
    }

    var currentAccessToken: String? {
        storedTokens?.accessToken
    }

    func bootstrap() async {
        guard let tokens = tokenStore.load() else {
            state = .signedOut
            return
        }

        storedTokens = tokens

        do {
            let me = try await userRepository.fetchCurrentUser()
            state = .signedIn(me)
        } catch {
            let wrappedError = AppError.wrap(error)
            if wrappedError.isConnectivityFailure {
                alertMessage = wrappedError.errorDescription
                state = .signedOut
                return
            }

            do {
                _ = try await refreshSession()
                let me = try await userRepository.fetchCurrentUser()
                state = .signedIn(me)
            } catch {
                clearSessionState()
                state = .signedOut
            }
        }
    }

    func signIn(with result: Result<ASAuthorization, any Error>) async {
        do {
            let credential = try authService.credential(from: result)
            let session = try await authRepository.signIn(with: credential)
            try applySession(session, appleUserID: credential.userID)
        } catch {
            clearSessionState()
            alertMessage = AppError.wrap(error).errorDescription
            state = .signedOut
        }
    }

    func refreshSession() async throws -> String {
        if let refreshTask {
            let session = try await refreshTask.value
            return session.tokens.accessToken
        }

        guard let refreshToken = storedTokens?.refreshToken, !refreshToken.isEmpty else {
            throw AppError.invalidSession
        }

        let task = Task { @MainActor [authRepository] in
            try await authRepository.refresh(refreshToken: refreshToken)
        }

        refreshTask = task
        defer { refreshTask = nil }

        do {
            let session = try await task.value
            try applySession(session, appleUserID: authService.lastAppleUserID())
            return session.tokens.accessToken
        } catch {
            clearSessionState()
            state = .signedOut
            throw AppError.invalidSession
        }
    }

    func handleUnauthorizedSession() async {
        clearSessionState()
        alertMessage = AppError.invalidSession.errorDescription
        state = .signedOut
    }

    func signOut(allDevices: Bool = false) async {
        let refreshToken = storedTokens?.refreshToken
        await onWillSignOut?()
        await authRepository.logout(refreshToken: refreshToken, allDevices: allDevices)
        clearSessionState()
        state = .signedOut
    }

    func deleteCurrentAccount() async throws {
        do {
            try await userRepository.deleteCurrentAccount()
        } catch AppError.invalidSession {
            clearSessionState()
            alertMessage = AppError.invalidSession.errorDescription
            state = .signedOut
            return
        }

        clearSessionState()
        alertMessage = "Your account has been deleted."
        state = .signedOut
    }

    func handleSceneDidBecomeActive() async {
        guard storedTokens != nil,
              let appleUserID = authService.lastAppleUserID() else {
            return
        }

        do {
            let credentialState = try await authService.credentialState(for: appleUserID)
            guard credentialState == .authorized else {
                clearSessionState()
                state = .signedOut
                alertMessage = "Your Apple sign-in is no longer valid. Sign in again to continue."
                return
            }
        } catch {
            // Ignore transient Apple credential state failures. Backend session remains authoritative.
        }
    }

    func setPreviewState(_ state: State) {
        self.state = state
    }

    func updateCurrentUser(_ user: User) {
        guard case .signedIn = state else {
            return
        }

        state = .signedIn(user)
    }

    private func applySession(_ session: AuthSession, appleUserID: String?) throws {
        storedTokens = session.tokens
        try tokenStore.save(session.tokens)
        authService.persistLastAppleUserID(appleUserID)
        state = .signedIn(session.user)
        alertMessage = nil
        refreshCenter.reset()
    }

    private func clearSessionState() {
        storedTokens = nil
        tokenStore.clear()
        authService.persistLastAppleUserID(nil)
        refreshCenter.reset()
        onDidClearSession?()
    }
}

@MainActor
final class AppRefreshCenter: ObservableObject {
    struct MapPinRefresh: Equatable {
        let id = UUID()
        let placeID: UUID
    }

    @Published private(set) var globalRevision = 0
    @Published private(set) var safetyRevision = 0
    @Published private(set) var mapRevision = 0
    @Published private(set) var mapPinRefresh: MapPinRefresh?

    func invalidateAll(refreshMap: Bool = true) {
        globalRevision &+= 1
        if refreshMap {
            mapRevision &+= 1
        }
    }

    func invalidateSafety() {
        // Recreate navigation/view models to immediately discard content that
        // may have been loaded before the block, including open photo sheets.
        safetyRevision &+= 1
        invalidateAll()
    }

    func invalidateMapPin(placeID: UUID) {
        mapPinRefresh = MapPinRefresh(placeID: placeID)
        invalidateAll(refreshMap: false)
    }

    func reset() {
        globalRevision = 0
        mapRevision = 0
        mapPinRefresh = nil
    }
}
