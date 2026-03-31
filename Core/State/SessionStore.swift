import AuthenticationServices
import Foundation

@MainActor
final class SessionStore: ObservableObject {
    enum State {
        case launching
        case signedOut
        case signedIn(User)
    }

    @Published private(set) var state: State = .launching
    @Published var alertMessage: String?

    private let authService: AuthServicing
    private let userRepository: UserProfileRepository
    private let signOutCleanup: @MainActor () -> Void

    init(
        authService: AuthServicing,
        userRepository: UserProfileRepository,
        signOutCleanup: @escaping @MainActor () -> Void = {}
    ) {
        self.authService = authService
        self.userRepository = userRepository
        self.signOutCleanup = signOutCleanup
    }

    var currentUser: User? {
        guard case .signedIn(let user) = state else {
            return nil
        }

        return user
    }

    func bootstrap() async {
        guard let appleUserID = authService.persistedAppleUserID() else {
            signOutCleanup()
            state = .signedOut
            return
        }

        do {
            let credentialState = try await authService.credentialState(for: appleUserID)
            guard credentialState == .authorized,
                  let user = try await userRepository.restoreAuthorizedUser(forAppleUserID: appleUserID) else {
                authService.persistActiveAppleUserID(nil)
                signOutCleanup()
                state = .signedOut
                return
            }

            state = .signedIn(user)
        } catch {
            authService.persistActiveAppleUserID(nil)
            signOutCleanup()
            state = .signedOut
            alertMessage = AppError.wrap(error).errorDescription
        }
    }

    func signIn(with result: Result<ASAuthorization, any Error>) async {
        do {
            let credential = try authService.credential(from: result)
            let user = try await userRepository.createOrUpdateSignedInUser(credential: credential)
            authService.persistActiveAppleUserID(credential.userID)
            state = .signedIn(user)
        } catch {
            signOutCleanup()
            alertMessage = AppError.wrap(error).errorDescription
            state = .signedOut
        }
    }

    func signOut() {
        authService.persistActiveAppleUserID(nil)
        signOutCleanup()
        state = .signedOut
    }

    func setPreviewState(_ state: State) {
        self.state = state
    }
}
