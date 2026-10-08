import Foundation

enum AppConfiguration {
    enum Environment: String, Sendable {
        case local = "Local"
        case prod = "Prod"
    }

    struct Current: Sendable {
        let environment: Environment
        let apiBaseURL: URL

        var isLocal: Bool {
            environment == .local
        }

        var isProduction: Bool {
            environment == .prod
        }
    }

    static let inviteURLScheme = "trustmap"
    static let inviteUniversalLinkBaseURL: URL? = nil
    static let networkTimeout: TimeInterval = 30
    static let preferredHandleMaxLength = 32
    static let privacyPolicyInfoKey = "TrustMapPrivacyPolicyURL"
    static let supportInfoKey = "TrustMapSupportURL"
    static let supportEmail = "support@trustmap.hubertik.com"
    static var supportEmailURL: URL? {
        URL(string: "mailto:\(supportEmail)")
    }
    static let termsOfServiceInfoKey = "TrustMapTermsOfServiceURL"
    static let environmentInfoKey = "TrustMapEnvironmentName"
    static let apiBaseURLInfoKey = "TrustMapAPIBaseURL"

    static var current: Current {
        let environment = resolvedEnvironment()
        let apiBaseURL = configuredAbsoluteURL(
            environmentKey: "TRUSTMAP_API_BASE_URL",
            infoDictionaryKey: apiBaseURLInfoKey
        )

        guard let apiBaseURL else {
            fail("TrustMap API base URL is missing. Set API_BASE_URL in the active build configuration.")
        }

        return Current(
            environment: environment,
            apiBaseURL: apiBaseURL
        )
    }

    static var environment: Environment {
        current.environment
    }

    static var apiBaseURL: URL {
        current.apiBaseURL
    }

    static var isRunningPreviews: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            || environment["XCODE_RUNNING_FOR_PLAYGROUNDS"] == "1"
    }

    static var privacyPolicyURL: URL? {
        configuredURL(
            environmentKey: "TRUSTMAP_PRIVACY_POLICY_URL",
            infoDictionaryKey: privacyPolicyInfoKey
        )
    }

    static var termsOfServiceURL: URL? {
        configuredURL(
            environmentKey: "TRUSTMAP_TERMS_OF_SERVICE_URL",
            infoDictionaryKey: termsOfServiceInfoKey
        )
    }

    static var supportURL: URL? {
        configuredURL(
            environmentKey: "TRUSTMAP_SUPPORT_URL",
            infoDictionaryKey: supportInfoKey
        )
    }

    static func resolvedBackendURL(from rawValue: String?) -> URL? {
        guard let rawValue else {
            return nil
        }

        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        if let absoluteURL = URL(string: trimmed),
           let scheme = absoluteURL.scheme,
           !scheme.isEmpty {
            return absoluteURL
        }

        if trimmed.hasPrefix("/") {
            guard var baseComponents = URLComponents(url: apiBaseURL, resolvingAgainstBaseURL: false),
                  let relativeComponents = URLComponents(string: trimmed) else {
                return nil
            }

            baseComponents.percentEncodedPath = relativeComponents.percentEncodedPath
            baseComponents.percentEncodedQuery = relativeComponents.percentEncodedQuery
            baseComponents.fragment = relativeComponents.fragment
            return baseComponents.url
        }

        return apiBaseURL.appendingPathComponent(trimmed)
    }

    private static func normalizedBaseURL(from url: URL) -> URL? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        components.path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let normalizedPath = components.path.isEmpty ? "" : "/\(components.path)"
        components.path = normalizedPath
        return components.url
    }

    private static func resolvedEnvironment() -> Environment {
        let rawValue = configuredString(
            environmentKey: "TRUSTMAP_ENVIRONMENT_NAME",
            infoDictionaryKey: environmentInfoKey
        )

        guard let rawValue else {
            fail("TrustMap environment is missing. Set TRUSTMAP_ENVIRONMENT_NAME in the active build configuration.")
        }

        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let environment = Environment(rawValue: trimmed) else {
            fail("Unsupported TrustMap environment '\(trimmed)'. Expected Local or Prod.")
        }

        return environment
    }

    private static func configuredAbsoluteURL(environmentKey: String, infoDictionaryKey: String) -> URL? {
        guard let rawValue = configuredString(environmentKey: environmentKey, infoDictionaryKey: infoDictionaryKey) else {
            return nil
        }

        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let scheme = url.scheme,
              !scheme.isEmpty else {
            return nil
        }

        return normalizedBaseURL(from: url)
    }

    private static func configuredString(environmentKey: String, infoDictionaryKey: String) -> String? {
        if let override = ProcessInfo.processInfo.environment[environmentKey] {
            return override
        }

        return Bundle.main.object(forInfoDictionaryKey: infoDictionaryKey) as? String
    }

    private static func configuredURL(environmentKey: String, infoDictionaryKey: String) -> URL? {
        if let override = ProcessInfo.processInfo.environment[environmentKey],
           let url = resolvedBackendURL(from: override) {
            return url
        }

        let rawValue = Bundle.main.object(forInfoDictionaryKey: infoDictionaryKey) as? String
        return resolvedBackendURL(from: rawValue)
    }

    private static func fail(_ message: String) -> Never {
        preconditionFailure(message)
    }
}
