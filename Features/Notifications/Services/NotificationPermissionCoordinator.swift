import Foundation

@MainActor
final class NotificationPermissionCoordinator {
    private let preferencesStore: AppPreferencesStore
    private let sessionStore: SessionStore
    private let userNotificationPermissionService: UserNotificationPermissionServicing
    private let pushDeviceTokenManager: PushDeviceTokenManager
    private let isPreview: Bool

    private var onboardingRequestTask: Task<Void, Never>?

    init(
        preferencesStore: AppPreferencesStore,
        sessionStore: SessionStore,
        userNotificationPermissionService: UserNotificationPermissionServicing,
        pushDeviceTokenManager: PushDeviceTokenManager,
        isPreview: Bool = AppConfiguration.isRunningPreviews
    ) {
        self.preferencesStore = preferencesStore
        self.sessionStore = sessionStore
        self.userNotificationPermissionService = userNotificationPermissionService
        self.pushDeviceTokenManager = pushDeviceTokenManager
        self.isPreview = isPreview
    }

    func requestOnboardingNotificationPermissionIfNeeded() {
        guard onboardingRequestTask == nil else {
            return
        }

        onboardingRequestTask = Task { @MainActor [weak self] in
            defer { self?.onboardingRequestTask = nil }
            await self?.requestOnboardingNotificationPermission()
        }
    }

    func handleAppDidBecomeActive() async {
        guard !isPreview else { return }

        await userNotificationPermissionService.refreshAuthorizationStatus()

        if userNotificationPermissionService.authorizationStatus.trustMapAllowsRemoteNotificationRegistration {
            userNotificationPermissionService.registerForRemoteNotificationsIfAuthorized()
            await pushDeviceTokenManager.uploadCurrentDeviceToken()
        }
    }

    private func requestOnboardingNotificationPermission() async {
        guard !isPreview,
              sessionStore.currentUser != nil,
              !preferencesStore.hasRequestedNotificationAuthorization else {
            return
        }

        await userNotificationPermissionService.refreshAuthorizationStatus()

        guard userNotificationPermissionService.authorizationStatus == .notDetermined else {
            if userNotificationPermissionService.authorizationStatus.trustMapAllowsRemoteNotificationRegistration {
                userNotificationPermissionService.registerForRemoteNotificationsIfAuthorized()
                await pushDeviceTokenManager.uploadCurrentDeviceToken()
            }
            return
        }

        try? await Task.sleep(for: .milliseconds(1400))
        guard !Task.isCancelled,
              sessionStore.currentUser != nil,
              !preferencesStore.hasRequestedNotificationAuthorization else {
            return
        }

        await userNotificationPermissionService.refreshAuthorizationStatus()
        guard userNotificationPermissionService.authorizationStatus == .notDetermined else {
            return
        }

        preferencesStore.hasRequestedNotificationAuthorization = true
        let granted = await userNotificationPermissionService.requestAuthorizationIfNeeded()
        if granted {
            await pushDeviceTokenManager.uploadCurrentDeviceToken()
        }
    }
}
