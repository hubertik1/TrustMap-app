import Foundation
import OSLog

@MainActor
final class PushDeviceTokenManager: PushDeviceTokenHandling {
    private let logger = Logger(subsystem: "TrustMap", category: "PushDeviceTokenManager")
    private let preferencesStore: AppPreferencesStore
    private let repository: PushDeviceTokenRepository
    private let sessionStore: SessionStore

    private var uploadTask: Task<Void, Never>?

    init(
        preferencesStore: AppPreferencesStore,
        repository: PushDeviceTokenRepository,
        sessionStore: SessionStore
    ) {
        self.preferencesStore = preferencesStore
        self.repository = repository
        self.sessionStore = sessionStore
    }

    func handleRegisteredDeviceToken(_ token: String) {
        let normalizedToken = token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedToken.isEmpty else {
            return
        }

        preferencesStore.currentAPNsDeviceToken = normalizedToken
        uploadCurrentDeviceTokenIfPossible()
    }

    func handleRemoteNotificationRegistrationFailure(_ error: Error) {
        logger.warning("APNs registration failed: \(error.localizedDescription, privacy: .public)")
    }

    func uploadCurrentDeviceTokenIfPossible() {
        uploadTask?.cancel()
        uploadTask = Task { @MainActor [weak self] in
            await self?.uploadCurrentDeviceToken()
        }
    }

    func uploadCurrentDeviceToken() async {
        guard sessionStore.currentUser != nil,
              let token = preferencesStore.currentAPNsDeviceToken,
              !token.isEmpty else {
            return
        }

        do {
            try await repository.registerDeviceToken(token)
        } catch {
            guard !Self.isCancellation(error) else { return }
            logger.warning("Device token upload failed and will be retried later: \(error.localizedDescription, privacy: .public)")
        }
    }

    func unregisterCurrentDeviceTokenForSignedInUser() async {
        guard let token = preferencesStore.currentAPNsDeviceToken,
              !token.isEmpty else {
            return
        }

        do {
            try await repository.unregisterDeviceToken(token)
        } catch {
            guard !Self.isCancellation(error) else { return }
            logger.warning("Device token unregister failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }
}
