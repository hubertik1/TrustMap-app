import AuthenticationServices
import Combine
import Foundation

@MainActor
final class SessionStore: ObservableObject, APISessionProviding {
    enum State {
        case launching
        case restorationFailed
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
    private let tokenStore: any SessionTokenStoring
    private let startupTimeout: Duration

    private var storedTokens: SessionTokens?
    private var refreshTask: Task<AuthSession, Error>?
    private var refreshTaskID: UUID?
    private var bootstrapTask: Task<User, Error>?
    private var sessionGeneration = 0

    init(
        authService: AuthServicing,
        authRepository: AuthRepository,
        refreshCenter: AppRefreshCenter,
        userRepository: UserProfileRepository,
        tokenStore: any SessionTokenStoring,
        startupTimeout: Duration = .seconds(AppConfiguration.sessionRestorationTimeout)
    ) {
        self.authService = authService
        self.authRepository = authRepository
        self.refreshCenter = refreshCenter
        self.userRepository = userRepository
        self.tokenStore = tokenStore
        self.startupTimeout = startupTimeout
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
        guard bootstrapTask == nil else { return }
        state = .launching
        alertMessage = nil
        guard let tokens = storedTokens ?? tokenStore.load() else {
            state = .signedOut
            return
        }

        storedTokens = tokens
        let generation = sessionGeneration
        let deadline = ContinuousClock.now.advanced(by: startupTimeout)
        let attempt = Task { @MainActor in
            do {
                if tokens.accessTokenExpiresAt <= .now.addingTimeInterval(30) {
                    _ = try await self.refreshSession()
                    guard let user = self.currentUser else { throw AppError.invalidSession }
                    return user
                }

                // Retry only the profile read, inside the API transport. A failed
                // token refresh must not cause this entire operation to be replayed.
                return try await self.userRepository.fetchCurrentUser(
                    timeoutInterval: AppConfiguration.sessionRestorationTimeout,
                    retryDeadline: deadline
                )
            } catch {
                // A gateway can fail immediately while the server is waking up.
                // Keep the startup grace period without replaying rotating tokens.
                if !Task.isCancelled, AppError.wrap(error).isConnectivityFailure {
                    try await Task.sleep(until: deadline, clock: .continuous)
                }
                throw error
            }
        }
        bootstrapTask = attempt
        let timeout = Task { @MainActor in
            try await Task.sleep(for: startupTimeout)
            attempt.cancel()
        }
        defer {
            timeout.cancel()
            bootstrapTask = nil
        }

        do {
            let me = try await withTaskCancellationHandler {
                try await attempt.value
            } onCancel: {
                attempt.cancel()
            }
            try Task.checkCancellation()
            guard generation == sessionGeneration else { return }
            state = .signedIn(me)
        } catch {
            guard generation == sessionGeneration else { return }
            let wrappedError = AppError.wrap(error)
            if wrappedError.invalidatesSession {
                clearSessionState()
                state = .signedOut
            } else {
                state = .restorationFailed
            }
        }
    }

    func signIn(with result: Result<ASAuthorization, any Error>) async {
        sessionGeneration &+= 1
        bootstrapTask?.cancel()
        refreshTask?.cancel()
        let generation = sessionGeneration
        do {
            let credential = try authService.credential(from: result)
            let session = try await authRepository.signIn(with: credential)
            try Task.checkCancellation()
            guard generation == sessionGeneration else { return }
            try applySession(session, appleUserID: credential.userID)
        } catch {
            guard generation == sessionGeneration else { return }
            alertMessage = AppError.wrap(error).errorDescription
            state = .signedOut
        }
    }

    func refreshSession() async throws -> String {
        if let refreshTask {
            let session = try await refreshTask.value
            try Task.checkCancellation()
            return session.tokens.accessToken
        }

        guard let refreshToken = storedTokens?.refreshToken, !refreshToken.isEmpty else {
            throw AppError.invalidSession
        }

        let generation = sessionGeneration
        let taskID = UUID()
        let task = Task { @MainActor in
            let session = try await self.authRepository.refresh(refreshToken: refreshToken)
            try Task.checkCancellation()
            guard generation == self.sessionGeneration else { throw CancellationError() }
            try self.applySession(session, appleUserID: self.authService.lastAppleUserID())
            return session
        }

        refreshTask = task
        refreshTaskID = taskID
        defer {
            if refreshTaskID == taskID {
                refreshTask = nil
                refreshTaskID = nil
            }
        }

        do {
            let session = try await withTaskCancellationHandler {
                try await task.value
            } onCancel: {
                task.cancel()
            }
            return session.tokens.accessToken
        } catch {
            let wrappedError = AppError.wrap(error)
            if generation == sessionGeneration, wrappedError.invalidatesSession {
                clearSessionState()
                state = .signedOut
            }
            throw error
        }
    }

    func handleUnauthorizedSession() async {
        clearSessionState()
        alertMessage = AppError.invalidSession.errorDescription
        state = .signedOut
    }

    func signOut(allDevices: Bool = false) async {
        sessionGeneration &+= 1
        bootstrapTask?.cancel()
        refreshTask?.cancel()
        let refreshToken = storedTokens?.refreshToken
        await onWillSignOut?()
        await authRepository.logout(refreshToken: refreshToken, allDevices: allDevices)
        clearSessionState()
        state = .signedOut
    }

    func deleteCurrentAccount() async throws {
        let result: UserProfileRepository.AccountDeletionResult
        do {
            result = try await userRepository.deleteCurrentAccount()
        } catch AppError.invalidSession {
            clearSessionState()
            alertMessage = AppError.invalidSession.errorDescription
            state = .signedOut
            return
        }

        clearSessionState()
        var message = L10n.yourAccountHasBeenDeleted
        if result.cleanupPending {
            message += L10n.remainingCleanupWillFinishAutomaticallyInTheBackground
        }
        if result.requiresManualAppleRevocation {
            message += L10n.toDisconnectSignInWithAppleOpenSettingsYourNameSignInWithAppleTrustmapThenTapDeleteAndConfi
        }
        alertMessage = message
        state = .signedOut
    }

    func handleSceneDidBecomeActive() async {
        guard storedTokens != nil,
              let appleUserID = authService.lastAppleUserID() else {
            return
        }

        let generation = sessionGeneration
        do {
            let credentialState = try await authService.credentialState(for: appleUserID)
            guard generation == sessionGeneration else { return }
            guard credentialState == .authorized else {
                clearSessionState()
                state = .signedOut
                alertMessage = L10n.yourAppleSignInIsNoLongerValidSignInAgainToContinue
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
        sessionGeneration &+= 1
        bootstrapTask?.cancel()
        refreshTask?.cancel()
        refreshTask = nil
        refreshTaskID = nil
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
