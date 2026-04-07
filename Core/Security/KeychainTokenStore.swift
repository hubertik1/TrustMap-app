import Foundation
import Security

struct SessionTokens: Codable, Equatable, Sendable {
    let accessToken: String
    let accessTokenExpiresAt: Date
    let refreshToken: String
    let refreshTokenExpiresAt: Date
}

final class KeychainTokenStore {
    private let service = "com.hubertik.TrustMap.session"
    private let account = "backend-session"

    func load() -> SessionTokens? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let data = item as? Data else {
            return nil
        }

        return try? JSONDecoder.sessionDecoder.decode(SessionTokens.self, from: data)
    }

    func save(_ tokens: SessionTokens) throws {
        let data = try JSONEncoder.sessionEncoder.encode(tokens)
        let updateStatus = SecItemUpdate(
            baseQuery as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )

        if updateStatus == errSecItemNotFound {
            var insert = baseQuery
            insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

            let insertStatus = SecItemAdd(insert as CFDictionary, nil)
            guard insertStatus == errSecSuccess else {
                throw AppError.underlying("The app could not save the session securely.")
            }

            return
        }

        guard updateStatus == errSecSuccess else {
            throw AppError.underlying("The app could not update the saved session.")
        }
    }

    func clear() {
        SecItemDelete(baseQuery as CFDictionary)
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

private extension JSONDecoder {
    static var sessionDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private extension JSONEncoder {
    static var sessionEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
