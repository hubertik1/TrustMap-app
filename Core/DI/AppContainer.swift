import Foundation

@MainActor
final class AppContainer: ObservableObject {
    let persistenceController: PersistenceController
    let photoStorageService: LocalPhotoStorageService
    let cloudKitSyncService: CloudKitSyncService
    let authService: AppleAuthenticationService
    let userRepository: UserProfileRepository
    let friendRepository: FriendRepository
    let categoryRepository: CategoryRepository
    let placeRepository: PlaceRepository
    let photoAssetRepository: PhotoAssetRepository
    let placeReviewRepository: PlaceReviewRepository
    let dishReviewRepository: DishReviewRepository
    let feedRepository: FeedRepository
    let mapSearchService: MapSearchService
    let sessionStore: SessionStore

    init(inMemory: Bool = false) {
        let persistenceController = PersistenceController(inMemory: inMemory)
        let photoStorageService = LocalPhotoStorageService()
        let cloudKitSyncService = CloudKitSyncService(
            forceDisabled: !AppConfiguration.cloudKitSyncEnabled || AppConfiguration.isRunningPreviews
        )
        let authService = AppleAuthenticationService()
        let userRepository = UserProfileRepository(
            persistenceController: persistenceController,
            cloudKitSyncService: cloudKitSyncService
        )
        let friendRepository = FriendRepository(
            persistenceController: persistenceController,
            cloudKitSyncService: cloudKitSyncService,
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
        let sessionStore = SessionStore(
            authService: authService,
            userRepository: userRepository
        )

        self.persistenceController = persistenceController
        self.photoStorageService = photoStorageService
        self.cloudKitSyncService = cloudKitSyncService
        self.authService = authService
        self.userRepository = userRepository
        self.friendRepository = friendRepository
        self.categoryRepository = categoryRepository
        self.placeRepository = placeRepository
        self.photoAssetRepository = photoAssetRepository
        self.placeReviewRepository = placeReviewRepository
        self.dishReviewRepository = dishReviewRepository
        self.feedRepository = feedRepository
        self.mapSearchService = mapSearchService
        self.sessionStore = sessionStore
    }
}
