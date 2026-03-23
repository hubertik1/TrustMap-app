import Foundation

struct AppleSignInCredential: Equatable, Sendable {
    let userID: String
    let displayName: String?
    let email: String?
}
