import AuthenticationServices
import Foundation

@MainActor
final class WelcomeViewModel: ObservableObject {
    @Published var isSigningIn = false
    @Published private(set) var demoErrorMessage: String?

    private let sessionStore: SessionStore
    private let authService: AuthServicing

    init(sessionStore: SessionStore, authService: AuthServicing) {
        self.sessionStore = sessionStore
        self.authService = authService
    }

    func configure(_ request: ASAuthorizationAppleIDRequest) {
        authService.configure(request)
    }

    func clearDemoError() {
        demoErrorMessage = nil
    }

    func signInToDemo(username: String, password: String) async -> Bool {
        guard !isSigningIn else { return false }
        isSigningIn = true
        demoErrorMessage = nil
        defer { isSigningIn = false }
        do {
            try await sessionStore.signInToDemo(username: username, password: password)
            return true
        } catch is CancellationError {
            return false
        } catch {
            demoErrorMessage = AppError.wrap(error).errorDescription
            return false
        }
    }

    func handleSignInCompletion(_ result: Result<ASAuthorization, any Error>) async {
        isSigningIn = true
        await sessionStore.signIn(with: result)
        isSigningIn = false
    }
}
