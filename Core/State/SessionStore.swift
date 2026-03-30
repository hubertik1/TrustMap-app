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

    init(
        authService: AuthServicing,
        userRepository: UserProfileRepository
    ) {
        self.authService = authService
        self.userRepository = userRepository
    }

    var currentUser: User? {
        guard case .signedIn(let user) = state else {
            return nil
        }

        return user
    }

    func bootstrap() async {
        guard let appleUserID = authService.persistedAppleUserID() else {
            state = .signedOut
            return
        }

        do {
            let credentialState = try await authService.credentialState(for: appleUserID)
            guard credentialState == .authorized,
                  let user = try await userRepository.restoreAuthorizedUser(forAppleUserID: appleUserID) else {
                authService.persistActiveAppleUserID(nil)
                state = .signedOut
                return
            }

            state = .signedIn(user)
        } catch {
            authService.persistActiveAppleUserID(nil)
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
            alertMessage = AppError.wrap(error).errorDescription
            state = .signedOut
        }
    }

    func signOut() {
        authService.persistActiveAppleUserID(nil)
        state = .signedOut
    }

    func setPreviewState(_ state: State) {
        self.state = state
    }
}
