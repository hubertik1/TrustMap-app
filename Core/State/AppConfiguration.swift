import Foundation

enum AppConfiguration {
    static let inviteURLScheme = "trustmap"
    static let inviteUniversalLinkBaseURL: URL? = nil
    static let networkTimeout: TimeInterval = 30
    static let preferredHandleMaxLength = 32

    static var apiBaseURL: URL {
        if let override = ProcessInfo.processInfo.environment["TRUSTMAP_API_BASE_URL"],
           let url = URL(string: override.trimmingCharacters(in: .whitespacesAndNewlines)),
           let normalized = normalizedBaseURL(from: url) {
            return normalized
        }

        if let rawValue = Bundle.main.object(forInfoDictionaryKey: "TrustMapAPIBaseURL") as? String,
           let url = URL(string: rawValue.trimmingCharacters(in: .whitespacesAndNewlines)),
           let normalized = normalizedBaseURL(from: url) {
            return normalized
        }

        return URL(string: "http://127.0.0.1:8080")!
    }

    static var isRunningPreviews: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            || environment["XCODE_RUNNING_FOR_PLAYGROUNDS"] == "1"
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
}
