import Foundation

@MainActor
final class AppContainer: ObservableObject {
    @Published var selectedTab: AppTab = .map

    let apiClient: APIClient
    let authService: AppleAuthenticationService
    let authRepository: AuthRepository
    let preferencesStore: AppPreferencesStore
    let refreshCenter: AppRefreshCenter
    let tokenStore: KeychainTokenStore
    let sessionStore: SessionStore
    let userRepository: UserProfileRepository
    let friendRepository: FriendRepository
    let placeRepository: PlaceRepository
    let categoryRepository: CategoryRepository
    let mapRepository: MapRepository
    let photoRepository: PhotoRepository
    let placeReviewRepository: PlaceReviewRepository
    let dishReviewRepository: DishReviewRepository
    let feedRepository: FeedRepository
    let notificationRepository: NotificationRepository
    let notificationBadgeStore: NotificationBadgeStore
    let userNotificationPermissionService: UserNotificationPermissionService
    let pushDeviceTokenRepository: PushDeviceTokenRepository
    let pushDeviceTokenManager: PushDeviceTokenManager
    let notificationPermissionCoordinator: NotificationPermissionCoordinator
    let mapSearchService: MapSearchService
    let userLocationService: UserLocationService

    init(preview: Bool = false) {
        let apiClient = APIClient(baseURL: AppConfiguration.apiBaseURL)
        let authService = AppleAuthenticationService()
        let authRepository = AuthRepository(apiClient: apiClient)
        let preferencesDefaults: UserDefaults
        if preview,
           let previewDefaults = UserDefaults(suiteName: "TrustMap.PreviewPreferences") {
            previewDefaults.removePersistentDomain(forName: "TrustMap.PreviewPreferences")
            preferencesDefaults = previewDefaults
        } else {
            preferencesDefaults = .standard
        }
        let preferencesStore = AppPreferencesStore(userDefaults: preferencesDefaults)
        let refreshCenter = AppRefreshCenter()
        let tokenStore = KeychainTokenStore()
        let userRepository = UserProfileRepository(apiClient: apiClient)
        let friendRepository = FriendRepository(apiClient: apiClient)
        let placeRepository = PlaceRepository(apiClient: apiClient)
        let categoryRepository = CategoryRepository(apiClient: apiClient)
        let photoRepository = PhotoRepository(apiClient: apiClient)
        let placeReviewRepository = PlaceReviewRepository(apiClient: apiClient, photoRepository: photoRepository)
        let dishReviewRepository = DishReviewRepository(apiClient: apiClient, photoRepository: photoRepository)
        let feedRepository = FeedRepository(apiClient: apiClient)
        let notificationRepository = NotificationRepository(apiClient: apiClient)
        let userNotificationPermissionService = UserNotificationPermissionService(isPreview: preview)
        let notificationBadgeStore = NotificationBadgeStore(
            notificationRepository: notificationRepository,
            userNotificationPermissionService: userNotificationPermissionService
        )
        let mapRepository = MapRepository(apiClient: apiClient)
        let mapSearchService = MapSearchService()
        let userLocationService = UserLocationService()
        let sessionStore = SessionStore(
            authService: authService,
            authRepository: authRepository,
            refreshCenter: refreshCenter,
            userRepository: userRepository,
            tokenStore: tokenStore
        )
        let pushDeviceTokenRepository = PushDeviceTokenRepository(apiClient: apiClient)
        let pushDeviceTokenManager = PushDeviceTokenManager(
            preferencesStore: preferencesStore,
            repository: pushDeviceTokenRepository,
            sessionStore: sessionStore
        )
        let notificationPermissionCoordinator = NotificationPermissionCoordinator(
            preferencesStore: preferencesStore,
            sessionStore: sessionStore,
            userNotificationPermissionService: userNotificationPermissionService,
            pushDeviceTokenManager: pushDeviceTokenManager,
            isPreview: preview
        )

        apiClient.sessionProvider = sessionStore
        sessionStore.onWillSignOut = { [weak pushDeviceTokenManager] in
            await pushDeviceTokenManager?.unregisterCurrentDeviceTokenForSignedInUser()
        }

        if !preview {
            PushDeviceTokenBridge.shared.configure(handler: pushDeviceTokenManager)
        }

        self.apiClient = apiClient
        self.authService = authService
        self.authRepository = authRepository
        self.preferencesStore = preferencesStore
        self.refreshCenter = refreshCenter
        self.tokenStore = tokenStore
        self.sessionStore = sessionStore
        self.userRepository = userRepository
        self.friendRepository = friendRepository
        self.placeRepository = placeRepository
        self.categoryRepository = categoryRepository
        self.mapRepository = mapRepository
        self.photoRepository = photoRepository
        self.placeReviewRepository = placeReviewRepository
        self.dishReviewRepository = dishReviewRepository
        self.feedRepository = feedRepository
        self.notificationRepository = notificationRepository
        self.notificationBadgeStore = notificationBadgeStore
        self.userNotificationPermissionService = userNotificationPermissionService
        self.pushDeviceTokenRepository = pushDeviceTokenRepository
        self.pushDeviceTokenManager = pushDeviceTokenManager
        self.notificationPermissionCoordinator = notificationPermissionCoordinator
        self.mapSearchService = mapSearchService
        self.userLocationService = userLocationService

        if preview {
            sessionStore.setPreviewState(.signedOut)
        }
    }
}
