import AuthenticationServices
import CryptoKit
import Foundation

@MainActor
protocol AuthServicing: AnyObject {
    func configure(_ request: ASAuthorizationAppleIDRequest)
    func credential(from result: Result<ASAuthorization, any Error>) throws -> AppleSignInCredential
    func credentialState(for userID: String) async throws -> ASAuthorizationAppleIDProvider.CredentialState
    func persistLastAppleUserID(_ userID: String?)
    func lastAppleUserID() -> String?
}

@MainActor
final class AppleAuthenticationService: NSObject, AuthServicing {
    private let provider = ASAuthorizationAppleIDProvider()
    private let persistedAppleUserIDKey = "trustmap.lastAppleUserID"
    private var activeRawNonce: String?

    func configure(_ request: ASAuthorizationAppleIDRequest) {
        let rawNonce = Self.makeRawNonce()
        activeRawNonce = rawNonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(rawNonce)
    }

    func credential(from result: Result<ASAuthorization, any Error>) throws -> AppleSignInCredential {
        switch result {
        case .failure(let error):
            throw AppError.authFailed(error.localizedDescription)

        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                throw AppError.authFailed(L10n.trustmapCouldNotReadTheAppleSignInResponse)
            }

            guard let rawNonce = activeRawNonce else {
                throw AppError.authFailed(L10n.theAppleSignInRequestCouldNotBeValidated)
            }

            activeRawNonce = nil

            guard let identityTokenData = credential.identityToken,
                  let identityToken = String(data: identityTokenData, encoding: .utf8),
                  !identityToken.isEmpty else {
                throw AppError.authFailed(L10n.appleDidNotReturnAValidIdentityToken)
            }

            let authorizationCode: String?
            if let authorizationCodeData = credential.authorizationCode {
                authorizationCode = String(data: authorizationCodeData, encoding: .utf8)
            } else {
                authorizationCode = nil
            }

            let formatter = PersonNameComponentsFormatter()
            formatter.style = .default
            let displayName = credential.fullName
                .flatMap { formatter.string(from: $0) }
                .flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty }

            return AppleSignInCredential(
                userID: credential.user,
                identityToken: identityToken,
                authorizationCode: authorizationCode,
                rawNonce: rawNonce,
                displayName: displayName,
                email: credential.email?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            )
        }
    }

    func credentialState(for userID: String) async throws -> ASAuthorizationAppleIDProvider.CredentialState {
        try await withCheckedThrowingContinuation { continuation in
            provider.getCredentialState(forUserID: userID) { state, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: state)
                }
            }
        }
    }

    func persistLastAppleUserID(_ userID: String?) {
        UserDefaults.standard.set(userID, forKey: persistedAppleUserIDKey)
    }

    func lastAppleUserID() -> String? {
        UserDefaults.standard.string(forKey: persistedAppleUserIDKey)
    }

    private static func makeRawNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        result.reserveCapacity(length)

        for _ in 0..<length {
            result.append(charset[Int.random(in: 0..<charset.count)])
        }

        return result
    }

    private static func sha256(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

@MainActor
final class AuthRepository {
    private struct AppleAuthPayload: Encodable {
        let identityToken: String
        let authorizationCode: String?
        let rawNonce: String
        let email: String?
        let displayName: String?
        let preferredHandle: String?
    }

    private struct RefreshTokenPayload: Encodable {
        let refreshToken: String
    }

    private struct LogoutPayload: Encodable {
        let refreshToken: String?
        let allDevices: Bool
    }

    struct SessionResponse: Decodable {
        let accessToken: String
        let accessTokenExpiresAtUtc: Date
        let refreshToken: String
        let refreshTokenExpiresAtUtc: Date
        let user: User
    }

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func signIn(with credential: AppleSignInCredential) async throws -> AuthSession {
        let preferredHandle = Self.preferredHandle(from: credential)
        let payload = AppleAuthPayload(
            identityToken: credential.identityToken,
            authorizationCode: credential.authorizationCode,
            rawNonce: credential.rawNonce,
            email: credential.email,
            displayName: credential.displayName,
            preferredHandle: preferredHandle
        )

        let request = APIRequest<SessionResponse>(
            method: .post,
            path: "auth/apple",
            body: .json(AnyEncodable(payload)),
            requiresAuthorization: false
        )

        let response = try await apiClient.send(request)
        return AuthSession(response: response)
    }

    func refresh(refreshToken: String) async throws -> AuthSession {
        let request = APIRequest<SessionResponse>(
            method: .post,
            path: "auth/refresh",
            body: .json(AnyEncodable(RefreshTokenPayload(refreshToken: refreshToken))),
            requiresAuthorization: false
        )

        let response = try await apiClient.send(request)
        return AuthSession(response: response)
    }

    func logout(refreshToken: String?, allDevices: Bool) async {
        let request = APIRequest<EmptyResponse>(
            method: .post,
            path: "auth/logout",
            body: .json(AnyEncodable(LogoutPayload(refreshToken: refreshToken, allDevices: allDevices))),
            acceptedStatusCodes: [204]
        )

        _ = try? await apiClient.send(request)
    }

    private static func preferredHandle(from credential: AppleSignInCredential) -> String? {
        let source = credential.displayName ?? credential.email?.components(separatedBy: "@").first
        guard let source else {
            return nil
        }

        let normalized = source.lowercased().filter {
            $0.unicodeScalars.allSatisfy(CharacterSet.alphanumerics.contains(_:))
        }
        guard !normalized.isEmpty else {
            return nil
        }

        return String(normalized.prefix(AppConfiguration.preferredHandleMaxLength))
    }
}

struct AuthSession: Sendable {
    let tokens: SessionTokens
    let user: User

    init(tokens: SessionTokens, user: User) {
        self.tokens = tokens
        self.user = user
    }

    init(response: AuthRepository.SessionResponse) {
        tokens = SessionTokens(
            accessToken: response.accessToken,
            accessTokenExpiresAt: response.accessTokenExpiresAtUtc,
            refreshToken: response.refreshToken,
            refreshTokenExpiresAt: response.refreshTokenExpiresAtUtc
        )
        user = response.user
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
