import Foundation

@MainActor
final class AppContainer: ObservableObject {
    let persistenceController: PersistenceController
    let photoStorageService: LocalPhotoStorageService
    let cloudKitSyncService: CloudKitSyncService
    let socialGraphCloudKitService: SocialGraphCloudKitService
    let authService: AppleAuthenticationService
    let pendingDeepLinkStore: PendingDeepLinkStore
    let inviteLinkBuilder: InviteLinkBuilder
    let deepLinkRouter: DeepLinkRouter
    let userRepository: UserProfileRepository
    let friendRepository: FriendRepository
    let categoryRepository: CategoryRepository
    let placeRepository: PlaceRepository
    let photoAssetRepository: PhotoAssetRepository
    let placeReviewRepository: PlaceReviewRepository
    let dishReviewRepository: DishReviewRepository
    let feedRepository: FeedRepository
    let mapSearchService: MapSearchService
    let userLocationService: UserLocationService
    let sessionStore: SessionStore

    init(inMemory: Bool = false) {
        let persistenceController = PersistenceController(inMemory: inMemory)
        let photoStorageService = LocalPhotoStorageService()
        let cloudKitSyncService = CloudKitSyncService(
            persistenceController: persistenceController,
            photoStorageService: photoStorageService,
            forceDisabled: !AppConfiguration.cloudKitSyncEnabled || AppConfiguration.isRunningPreviews
        )
        let socialGraphCloudKitService = SocialGraphCloudKitService(
            forceDisabled: !AppConfiguration.socialGraphCloudKitEnabled || AppConfiguration.isRunningPreviews || inMemory
        )
        let authService = AppleAuthenticationService()
        let pendingDeepLinkStore = PendingDeepLinkStore()
        let inviteLinkBuilder = InviteLinkBuilder()
        let deepLinkRouter = DeepLinkRouter(
            inviteLinkBuilder: inviteLinkBuilder,
            pendingDeepLinkStore: pendingDeepLinkStore
        )
        let userRepository = UserProfileRepository(
            persistenceController: persistenceController,
            cloudKitSyncService: cloudKitSyncService,
            socialGraphService: socialGraphCloudKitService
        )
        let friendRepository = FriendRepository(
            persistenceController: persistenceController,
            cloudKitSyncService: cloudKitSyncService,
            socialGraphService: socialGraphCloudKitService,
            userRepository: userRepository
        )
        let categoryRepository = CategoryRepository(
            persistenceController: persistenceController,
            cloudKitSyncService: cloudKitSyncService
        )
        let placeRepository = PlaceRepository(
            persistenceController: persistenceController,
            cloudKitSyncService: cloudKitSyncService
        )
        let photoAssetRepository = PhotoAssetRepository(
            persistenceController: persistenceController,
            storageService: photoStorageService,
            cloudKitSyncService: cloudKitSyncService
        )
        let placeReviewRepository = PlaceReviewRepository(
            persistenceController: persistenceController,
            cloudKitSyncService: cloudKitSyncService,
            photoAssetRepository: photoAssetRepository,
            categoryRepository: categoryRepository
        )
        let dishReviewRepository = DishReviewRepository(
            persistenceController: persistenceController,
            cloudKitSyncService: cloudKitSyncService,
            photoAssetRepository: photoAssetRepository
        )
        let feedRepository = FeedRepository(persistenceController: persistenceController)
        let mapSearchService = MapSearchService()
        let userLocationService = UserLocationService()
        let sessionStore = SessionStore(
            authService: authService,
            userRepository: userRepository
        )

        self.persistenceController = persistenceController
        self.photoStorageService = photoStorageService
        self.cloudKitSyncService = cloudKitSyncService
        self.socialGraphCloudKitService = socialGraphCloudKitService
        self.authService = authService
        self.pendingDeepLinkStore = pendingDeepLinkStore
        self.inviteLinkBuilder = inviteLinkBuilder
        self.deepLinkRouter = deepLinkRouter
        self.userRepository = userRepository
        self.friendRepository = friendRepository
        self.categoryRepository = categoryRepository
        self.placeRepository = placeRepository
        self.photoAssetRepository = photoAssetRepository
        self.placeReviewRepository = placeReviewRepository
        self.dishReviewRepository = dishReviewRepository
        self.feedRepository = feedRepository
        self.mapSearchService = mapSearchService
        self.userLocationService = userLocationService
        self.sessionStore = sessionStore
    }
}
