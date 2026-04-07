import Foundation

struct AppleSignInCredential: Equatable, Sendable {
    let userID: String
    let identityToken: String
    let authorizationCode: String?
    let rawNonce: String
    let displayName: String?
    let email: String?
}
