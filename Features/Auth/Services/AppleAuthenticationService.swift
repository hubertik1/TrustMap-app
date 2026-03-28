import AuthenticationServices
import Foundation
import Security

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
        static let cachedProfilePrefix = "cachedAppleProfile"
        static let keychainService = "com.hubertik.TrustMap.appleProfile"
    }

    private let provider = ASAuthorizationAppleIDProvider()
    private let defaults: UserDefaults
    private let nameFormatter = PersonNameComponentsFormatter()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        nameFormatter.style = .default
    }

    func configure(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }

    func credential(from result: Result<ASAuthorization, any Error>) throws -> AppleSignInCredential {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                throw AppError.authFailed("Sign in with Apple did not return a valid credential.")
            }

            let displayName = sanitizedValue(formattedDisplayName(from: credential.fullName)) ?? cachedDisplayName(for: credential.user)
            let email = sanitizedValue(credential.email) ?? cachedEmail(for: credential.user)
            persistCachedProfile(displayName: displayName, email: email, for: credential.user)

            return AppleSignInCredential(
                userID: credential.user,
                displayName: displayName,
                email: email
            )

        case .failure(let error):
            throw Self.mapAuthorizationError(error)
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
                    continuation.resume(throwing: Self.mapAuthorizationError(error))
                } else {
                    continuation.resume(returning: state)
                }
            }
        }
    }

    private func formattedDisplayName(from components: PersonNameComponents?) -> String? {
        guard let components else {
            return nil
        }

        let manualName = [
            components.givenName,
            components.middleName,
            components.familyName
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: " ")

        if !manualName.isEmpty {
            return manualName
        }

        let formattedName = nameFormatter.string(from: components).trimmingCharacters(in: .whitespacesAndNewlines)
        return formattedName.isEmpty ? nil : formattedName
    }

    private func persistCachedProfile(displayName: String?, email: String?, for userID: String) {
        if let displayName {
            saveCachedProfileValue(displayName, field: "displayName", for: userID)
        }

        if let email {
            saveCachedProfileValue(email, field: "email", for: userID)
        }
    }

    private func cachedDisplayName(for userID: String) -> String? {
        cachedProfileValue(field: "displayName", for: userID)
    }

    private func cachedEmail(for userID: String) -> String? {
        cachedProfileValue(field: "email", for: userID)
    }

    private func cachedProfileKey(field: String, userID: String) -> String {
        "\(StorageKeys.cachedProfilePrefix).\(userID).\(field)"
    }

    private func cachedProfileValue(field: String, for userID: String) -> String? {
        let account = cachedProfileKey(field: field, userID: userID)

        if let keychainValue = sanitizedValue(loadKeychainValue(account: account)) {
            return keychainValue
        }

        guard let legacyValue = sanitizedValue(defaults.string(forKey: account)) else {
            return nil
        }

        saveCachedProfileValue(legacyValue, field: field, for: userID)
        return legacyValue
    }

    private func saveCachedProfileValue(_ value: String, field: String, for userID: String) {
        let account = cachedProfileKey(field: field, userID: userID)
        defaults.set(value, forKey: account)
        saveKeychainValue(value, account: account)
    }

    private func saveKeychainValue(_ value: String, account: String) {
        guard let data = value.data(using: .utf8) else {
            return
        }

        let query = keychainQuery(account: account)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecSuccess {
            return
        }

        guard updateStatus == errSecItemNotFound else {
            return
        }

        var insertQuery = query
        insertQuery[kSecValueData as String] = data
        insertQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(insertQuery as CFDictionary, nil)
    }

    private func loadKeychainValue(account: String) -> String? {
        var query = keychainQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    private func keychainQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: StorageKeys.keychainService,
            kSecAttrAccount as String: account
        ]
    }

    private func sanitizedValue(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }

        return trimmed
    }

    private nonisolated static func mapAuthorizationError(_ error: Error) -> AppError {
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

        case .credentialExport, .credentialImport, .matchedExcludedCredential, .preferSignInWithApple:
            return .authFailed("Sign in with Apple failed because the selected credential is unavailable for this request. Try again with a different account or credential.")

        case .deviceNotConfiguredForPasskeyCreation:
            return .authFailed("Sign in with Apple is unavailable because this device is not configured for passkey creation.")

        @unknown default:
            return .authFailed("Sign in with Apple failed. Verify the target capabilities and signing configuration, then try again.")
        }
    }
}
