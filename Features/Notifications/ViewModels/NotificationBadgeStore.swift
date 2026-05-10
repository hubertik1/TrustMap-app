import Foundation
import OSLog
import UIKit
import UserNotifications

@MainActor
final class NotificationBadgeStore: ObservableObject {
    @Published private(set) var unreadCount: Int = 0

    private let logger = Logger(subsystem: "TrustMap", category: "NotificationBadgeStore")
    private let notificationRepository: NotificationRepository
    private let userNotificationPermissionService: (any UserNotificationPermissionServicing)?

    init(
        notificationRepository: NotificationRepository,
        userNotificationPermissionService: (any UserNotificationPermissionServicing)? = nil
    ) {
        self.notificationRepository = notificationRepository
        self.userNotificationPermissionService = userNotificationPermissionService
    }

    func loadUnreadCount() async {
        do {
            unreadCount = try await notificationRepository.fetchUnreadCount()
            updateApplicationIconBadge(to: unreadCount)
        } catch {
            guard !Self.isCancellation(error) else { return }
            logger.error("Unable to load unread notification count: \(error.localizedDescription, privacy: .public)")
        }
    }

    func reset() {
        unreadCount = 0
        updateApplicationIconBadge(to: 0)
    }

    func decrementIfUnread(_ notification: TrustMapNotification) {
        guard notification.isUnread else {
            return
        }

        unreadCount = max(0, unreadCount - 1)
        updateApplicationIconBadge(to: unreadCount)
    }

    func setReadAll() {
        unreadCount = 0
        updateApplicationIconBadge(to: 0)
    }

    private func updateApplicationIconBadge(to count: Int) {
        guard !AppConfiguration.isRunningPreviews,
              userNotificationPermissionService?.authorizationStatus.trustMapAllowsRemoteNotificationRegistration == true else {
            return
        }

        if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(count) { [logger] error in
                if let error {
                    logger.warning("Unable to update app icon badge: \(error.localizedDescription, privacy: .public)")
                }
            }
        } else {
            UIApplication.shared.applicationIconBadgeNumber = count
        }
    }

    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }
}
