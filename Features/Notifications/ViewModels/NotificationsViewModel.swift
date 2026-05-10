import Foundation
import OSLog

@MainActor
final class NotificationsViewModel: ObservableObject {
    @Published private(set) var notifications: [TrustMapNotification] = []
    @Published private(set) var hasLoaded = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let logger = Logger(subsystem: "TrustMap", category: "NotificationsViewModel")
    private let notificationRepository: NotificationRepository
    private let badgeStore: NotificationBadgeStore

    init(
        notificationRepository: NotificationRepository,
        badgeStore: NotificationBadgeStore
    ) {
        self.notificationRepository = notificationRepository
        self.badgeStore = badgeStore
    }

    var hasUnreadNotifications: Bool {
        notifications.contains(where: \.isUnread)
    }

    var isEmpty: Bool {
        hasLoaded && notifications.isEmpty
    }

    func load() async {
        await loadNotifications(showsLoadingIndicator: !hasLoaded)
    }

    func refresh() async {
        await loadNotifications(showsLoadingIndicator: false)
    }

    @discardableResult
    func markAsRead(_ notification: TrustMapNotification) async -> Bool {
        guard notification.isUnread else {
            return true
        }

        do {
            try await notificationRepository.markAsRead(id: notification.id)
            if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
                notifications[index] = notifications[index].markedRead()
            }
            badgeStore.decrementIfUnread(notification)
            return true
        } catch {
            guard !Self.isCancellation(error) else { return false }
            logger.error("Unable to mark notification read: \(error.localizedDescription, privacy: .public)")
            errorMessage = AppError.wrap(error).errorDescription
            return false
        }
    }

    func markAllAsRead() async {
        do {
            try await notificationRepository.markAllAsRead()
            notifications = notifications.map { $0.markedRead() }
            badgeStore.setReadAll()
            errorMessage = nil
        } catch {
            guard !Self.isCancellation(error) else { return }
            logger.error("Unable to mark all notifications read: \(error.localizedDescription, privacy: .public)")
            errorMessage = AppError.wrap(error).errorDescription
        }
    }

    private func loadNotifications(showsLoadingIndicator: Bool) async {
        if showsLoadingIndicator {
            isLoading = true
        }
        defer { isLoading = false }

        do {
            notifications = try await notificationRepository.fetchNotifications()
            hasLoaded = true
            errorMessage = nil
            await badgeStore.loadUnreadCount()
        } catch {
            guard !Self.isCancellation(error) else { return }
            logger.error("Unable to load notifications: \(error.localizedDescription, privacy: .public)")
            errorMessage = AppError.wrap(error).errorDescription
            hasLoaded = true
            if notifications.isEmpty {
                notifications = []
            }
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
