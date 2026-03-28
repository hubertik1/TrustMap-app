import Foundation

protocol InviteLinkBuilding {
    func inviteURL(for token: String) throws -> URL
    func inviteToken(from url: URL) -> String?
}

struct InviteLinkBuilder: InviteLinkBuilding {
    private let customScheme: String
    private let universalLinkBaseURL: URL?

    init(
        customScheme: String = AppConfiguration.inviteURLScheme,
        universalLinkBaseURL: URL? = AppConfiguration.inviteUniversalLinkBaseURL
    ) {
        self.customScheme = customScheme
        self.universalLinkBaseURL = universalLinkBaseURL
    }

    func inviteURL(for token: String) throws -> URL {
        guard !token.isEmpty else {
            throw AppError.validationFailure("A valid invite token is required.")
        }

        if let universalLinkBaseURL {
            guard var components = URLComponents(
                url: universalLinkBaseURL,
                resolvingAgainstBaseURL: false
            ) else {
                throw AppError.validationFailure("The invite link configuration is invalid.")
            }

            let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            components.path = "/" + [basePath, "invite"].filter { !$0.isEmpty }.joined(separator: "/")
            components.queryItems = [URLQueryItem(name: "token", value: token)]

            guard let url = components.url else {
                throw AppError.validationFailure("The invite link configuration is invalid.")
            }

            return url
        }

        var components = URLComponents()
        components.scheme = customScheme
        components.host = "invite"
        components.queryItems = [URLQueryItem(name: "token", value: token)]

        guard let url = components.url else {
            throw AppError.validationFailure("The invite link configuration is invalid.")
        }

        return url
    }

    func inviteToken(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let token = components.queryItems?.first(where: { $0.name == "token" })?.value?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty else {
            return nil
        }

        let normalizedPath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        let normalizedHost = components.host?.lowercased()
        let normalizedScheme = components.scheme?.lowercased()
        let isCustomInviteURL =
            normalizedScheme == customScheme.lowercased()
            && (normalizedHost == "invite" || normalizedPath == "invite")

        let isUniversalInviteURL: Bool
        if let universalLinkBaseURL,
           let universalComponents = URLComponents(url: universalLinkBaseURL, resolvingAgainstBaseURL: false) {
            let universalScheme = universalComponents.scheme?.lowercased()
            let universalHost = universalComponents.host?.lowercased()
            let basePath = universalComponents.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
            let expectedPath = [basePath, "invite"].filter { !$0.isEmpty }.joined(separator: "/")

            isUniversalInviteURL =
                normalizedScheme == universalScheme
                && normalizedHost == universalHost
                && normalizedPath == expectedPath
        } else {
            isUniversalInviteURL = normalizedPath == "invite"
        }

        return (isCustomInviteURL || isUniversalInviteURL) ? token : nil
    }
}
