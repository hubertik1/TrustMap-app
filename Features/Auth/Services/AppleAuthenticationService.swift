import AuthenticationServices
import Foundation

@MainActor
protocol AuthServicing: AnyObject {
    func configure(_ request: ASAuthorizationAppleIDRequest)
    func credential(from result: Result<ASAuthorization, any Error>) throws -> AppleSignInCredential
    func persistedAppleUserID() -> String?
    func persistActiveAppleUserID(_ userID: String?)
    func credentialState(for userID: String) async throws -> ASAuthorizationAppleIDProvider.CredentialState
}

@MainActor
final class AppleAuthenticationService: AuthServicing {
    private enum StorageKeys {
        static let activeAppleUserID = "activeAppleUserID"
    }

    private let provider = ASAuthorizationAppleIDProvider()
    private let defaults: UserDefaults
    private let nameFormatter = PersonNameComponentsFormatter()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        nameFormatter.style = .default
    }

    func configure(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName]
    }

    func credential(from result: Result<ASAuthorization, any Error>) throws -> AppleSignInCredential {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                throw AppError.authFailed("Sign in with Apple did not return a valid credential.")
            }

            let formattedName = credential.fullName
                .flatMap { nameFormatter.string(from: $0).trimmingCharacters(in: .whitespacesAndNewlines) }

            return AppleSignInCredential(
                userID: credential.user,
                displayName: formattedName?.isEmpty == true ? nil : formattedName
            )

        case .failure(let error):
            throw mapAuthorizationError(error)
        }
    }

    func persistedAppleUserID() -> String? {
        defaults.string(forKey: StorageKeys.activeAppleUserID)
    }

    func persistActiveAppleUserID(_ userID: String?) {
        defaults.set(userID, forKey: StorageKeys.activeAppleUserID)
    }

    func credentialState(for userID: String) async throws -> ASAuthorizationAppleIDProvider.CredentialState {
        try await withCheckedThrowingContinuation { continuation in
            provider.getCredentialState(forUserID: userID) { state, error in
                if let error {
                    continuation.resume(throwing: self.mapAuthorizationError(error))
                } else {
                    continuation.resume(returning: state)
                }
            }
        }
    }

    private func mapAuthorizationError(_ error: Error) -> AppError {
        guard let authorizationError = error as? ASAuthorizationError else {
            return AppError.wrap(error)
        }

        switch authorizationError.code {
        case .canceled:
            return .authFailed("Sign in with Apple was canceled.")

        case .unknown, .failed, .invalidResponse, .notHandled:
            return .authFailed(
                "Sign in with Apple failed. Check that the TrustMap target has the Sign in with Apple capability enabled, that a Development Team is selected in Signing & Capabilities, and that the device or simulator is signed into an Apple ID."
            )

        case .notInteractive:
            return .authFailed("Sign in with Apple is currently unavailable because the request is not running in an interactive UI context.")

        @unknown default:
            return .authFailed("Sign in with Apple failed. Verify the target capabilities and signing configuration, then try again.")
        }
    }
}
