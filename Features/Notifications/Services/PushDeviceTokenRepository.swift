import Foundation

@MainActor
final class PushDeviceTokenRepository {
    private struct RegisterDeviceTokenRequest: Encodable {
        let token: String
        let platform: String
        let environment: String
        let appVersion: String?
        let buildNumber: String?
    }

    private let apiClient: APIClient

    private(set) var currentDeviceToken: String?

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func registerDeviceToken(_ token: String) async throws {
        let normalizedToken = Self.normalizedToken(token)
        guard !normalizedToken.isEmpty else {
            return
        }

        currentDeviceToken = normalizedToken
        _ = try await apiClient.send(
            APIRequest<EmptyResponse>(
                method: .post,
                path: "me/device-tokens",
                body: .json(AnyEncodable(RegisterDeviceTokenRequest(
                    token: normalizedToken,
                    platform: "ios",
                    environment: Self.apnsEnvironment,
                    appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                    buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String
                ))),
                acceptedStatusCodes: [200, 204]
            )
        )
    }

    func unregisterCurrentDeviceToken() async throws {
        guard let currentDeviceToken else {
            return
        }

        try await unregisterDeviceToken(currentDeviceToken)
    }

    func unregisterDeviceToken(_ token: String) async throws {
        let normalizedToken = Self.normalizedToken(token)
        guard !normalizedToken.isEmpty else {
            return
        }

        _ = try await apiClient.send(
            APIRequest<EmptyResponse>(
                method: .delete,
                path: "me/device-tokens/\(normalizedToken)",
                acceptedStatusCodes: [204]
            )
        )

        if currentDeviceToken == normalizedToken {
            currentDeviceToken = nil
        }
    }

    private static var apnsEnvironment: String {
        AppConfiguration.environment == .prod ? "production" : "development"
    }

    private static func normalizedToken(_ token: String) -> String {
        token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
