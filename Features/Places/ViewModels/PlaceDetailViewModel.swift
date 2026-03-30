import Foundation

@MainActor
final class PlaceDetailViewModel: ObservableObject {
    @Published private(set) var averageRating: Double?
    @Published private(set) var placeReviews: [PlaceReview] = []
    @Published private(set) var dishReviews: [DishReview] = []
    @Published private(set) var placePhotos: [PhotoAsset] = []
    @Published private(set) var categoryNames: [String] = []
    @Published private(set) var authorNames: [UUID: String] = [:]
    @Published private(set) var reviewPhotos: [UUID: [PhotoAsset]] = [:]
    @Published private(set) var dishPhotos: [UUID: PhotoAsset] = [:]
    @Published private(set) var currentUserPlaceReview: PlaceReview?
    @Published private(set) var currentUserID: UUID?
    @Published var editingDishReview: DishReview?
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var isPresentingAddPlaceReview = false
    @Published var isPresentingAddDishReview = false

    let place: Place

    private let sessionStore: SessionStore
    private let cloudKitSyncService: CloudKitSyncService
    private let friendRepository: FriendRepository
    private let userRepository: UserProfileRepository
    private let categoryRepository: CategoryRepository
    private let photoAssetRepository: PhotoAssetRepository
    private let placeReviewRepository: PlaceReviewRepository
    private let dishReviewRepository: DishReviewRepository

    init(
        place: Place,
        sessionStore: SessionStore,
        cloudKitSyncService: CloudKitSyncService,
        friendRepository: FriendRepository,
        userRepository: UserProfileRepository,
        categoryRepository: CategoryRepository,
        photoAssetRepository: PhotoAssetRepository,
        placeReviewRepository: PlaceReviewRepository,
        dishReviewRepository: DishReviewRepository
    ) {
        self.place = place
        self.sessionStore = sessionStore
        self.cloudKitSyncService = cloudKitSyncService
        self.friendRepository = friendRepository
        self.userRepository = userRepository
        self.categoryRepository = categoryRepository
        self.photoAssetRepository = photoAssetRepository
        self.placeReviewRepository = placeReviewRepository
        self.dishReviewRepository = dishReviewRepository
    }

    func load() async {
        guard let currentUser = sessionStore.currentUser else {
            errorMessage = AppError.missingCurrentUser.errorDescription
            currentUserPlaceReview = nil
            currentUserID = nil
            return
        }

        isLoading = true
        errorMessage = nil
        currentUserID = currentUser.id

        do {
            let friends = try await friendRepository.acceptedFriends(for: currentUser.id)
            try await cloudKitSyncService.refreshFriendVisibleContent(for: currentUser, friends: friends)
            let friendIDs = Set(friends.map(\.id))
            placeReviews = try placeReviewRepository.reviews(for: place.id, visibleTo: currentUser.id, friendIDs: friendIDs)
            currentUserPlaceReview = placeReviews.first(where: { $0.authorUserId == currentUser.id })
            dishReviews = try dishReviewRepository.reviews(for: place.id, visibleTo: currentUser.id, friendIDs: friendIDs)
            averageRating = try placeReviewRepository.averageRating(for: place.id, visibleTo: currentUser.id, friendIDs: friendIDs)
            categoryNames = try categoryRepository.categoryNames(forPlace: place.id)
            placePhotos = try photoAssetRepository.photos(
                for: place.id,
                visiblePlaceReviewIDs: Set(placeReviews.map(\.id)),
                visibleDishReviewIDs: Set(dishReviews.map(\.id))
            )
            reviewPhotos = Dictionary(grouping: placePhotos.compactMap { asset in
                asset.placeReviewId.map { (reviewID: $0, asset: asset) }
            }, by: \.reviewID).mapValues { $0.map(\.asset) }
            dishPhotos = Dictionary(uniqueKeysWithValues: placePhotos.compactMap { asset in
                guard let dishReviewId = asset.dishReviewId else {
                    return nil
                }
                return (dishReviewId, asset)
            })

            let visibleAuthorIDs = Set(placeReviews.map(\.authorUserId) + dishReviews.map(\.authorUserId))
            let allUsers = try userRepository.allKnownUsers()
            authorNames = Dictionary(uniqueKeysWithValues: allUsers.compactMap { user in
                visibleAuthorIDs.contains(user.id) ? (user.id, user.displayName) : nil
            })
            authorNames[currentUser.id] = currentUser.displayName
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
        }

        isLoading = false
    }

    var placeReviewButtonTitle: String {
        currentUserPlaceReview == nil ? "Add Place Review" : "Edit Place Review"
    }

    func canEdit(_ review: DishReview) -> Bool {
        review.authorUserId == currentUserID
    }

    func beginEditing(_ review: DishReview) {
        guard canEdit(review) else {
            return
        }

        editingDishReview = review
    }

    func dishPhotoData(for review: DishReview) -> Data? {
        guard let asset = dishPhotos[review.id] else {
            return nil
        }

        return imageData(for: asset)
    }

    func authorName(for userID: UUID) -> String {
        authorNames[userID] ?? "Friend"
    }

    func imageData(for asset: PhotoAsset) -> Data? {
        photoAssetRepository.imageData(for: asset)
    }
}
