import Foundation
import UIKit
import UserNotifications

@MainActor
protocol UserNotificationPermissionServicing: AnyObject {
    var authorizationStatus: UNAuthorizationStatus { get }
    var onAuthorizationChange: ((UNAuthorizationStatus) -> Void)? { get set }

    func refreshAuthorizationStatus() async
    func requestAuthorizationIfNeeded() async -> Bool
    func registerForRemoteNotificationsIfAuthorized()
    func openSystemNotificationSettings()
}

@MainActor
final class UserNotificationPermissionService: UserNotificationPermissionServicing {
    var onAuthorizationChange: ((UNAuthorizationStatus) -> Void)?

    private let notificationCenter: UNUserNotificationCenter
    private let isPreview: Bool

    private(set) var authorizationStatus: UNAuthorizationStatus {
        didSet {
            guard oldValue != authorizationStatus else { return }
            onAuthorizationChange?(authorizationStatus)
        }
    }

    init(
        notificationCenter: UNUserNotificationCenter = .current(),
        isPreview: Bool = AppConfiguration.isRunningPreviews
    ) {
        self.notificationCenter = notificationCenter
        self.isPreview = isPreview
        self.authorizationStatus = isPreview ? .authorized : .notDetermined
    }

    func refreshAuthorizationStatus() async {
        guard !isPreview else {
            authorizationStatus = .authorized
            return
        }

        let status = await withCheckedContinuation { continuation in
            notificationCenter.getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
        authorizationStatus = status
    }

    func requestAuthorizationIfNeeded() async -> Bool {
        guard !isPreview else {
            authorizationStatus = .authorized
            return true
        }

        await refreshAuthorizationStatus()

        switch authorizationStatus {
        case .notDetermined:
            do {
                _ = try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
            } catch {
                await refreshAuthorizationStatus()
                return authorizationStatus.trustMapAllowsRemoteNotificationRegistration
            }

            await refreshAuthorizationStatus()

        case .authorized, .provisional, .ephemeral, .denied:
            break

        @unknown default:
            return false
        }

        if authorizationStatus.trustMapAllowsRemoteNotificationRegistration {
            registerForRemoteNotificationsIfAuthorized()
        }

        return authorizationStatus.trustMapAllowsRemoteNotificationRegistration
    }

    func registerForRemoteNotificationsIfAuthorized() {
        guard !isPreview,
              authorizationStatus.trustMapAllowsRemoteNotificationRegistration else {
            return
        }

        UIApplication.shared.registerForRemoteNotifications()
    }

    func openSystemNotificationSettings() {
        guard !isPreview else { return }

        let urlString: String
        if #available(iOS 16.0, *) {
            urlString = UIApplication.openNotificationSettingsURLString
        } else {
            urlString = UIApplication.openSettingsURLString
        }

        guard let settingsURL = URL(string: urlString) else {
            return
        }

        UIApplication.shared.open(settingsURL)
    }
}
