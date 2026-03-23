import AuthenticationServices
import Foundation

@MainActor
final class WelcomeViewModel: ObservableObject {
    @Published var isSigningIn = false

    private let sessionStore: SessionStore
    private let authService: AuthServicing

    init(sessionStore: SessionStore, authService: AuthServicing) {
        self.sessionStore = sessionStore
        self.authService = authService
    }

    func configure(_ request: ASAuthorizationAppleIDRequest) {
        authService.configure(request)
    }

    func handleSignInCompletion(_ result: Result<ASAuthorization, any Error>) async {
        isSigningIn = true
        await sessionStore.signIn(with: result)
        isSigningIn = false
    }
}
