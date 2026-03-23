import Foundation

enum AppConfiguration {
    // Enable after adding iCloud + CloudKit capabilities and a real container.
    static let cloudKitSyncEnabled = false

    static var isRunningPreviews: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            || environment["XCODE_RUNNING_FOR_PLAYGROUNDS"] == "1"
    }
}
