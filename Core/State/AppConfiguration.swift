import Foundation

enum AppConfiguration {
    // Enable after adding iCloud + CloudKit capabilities and a real container.
    static let cloudKitSyncEnabled = false
    static let socialGraphCloudKitEnabled = true
    static let inviteURLScheme = "trustmap"
    static let inviteUniversalLinkBaseURL: URL? = nil
    static let friendInviteLifetime: TimeInterval = 60 * 60 * 24 * 7

    static var isRunningPreviews: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            || environment["XCODE_RUNNING_FOR_PLAYGROUNDS"] == "1"
    }
}
