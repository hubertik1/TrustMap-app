import Foundation
import OSLog

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var user: User?
    @Published private(set) var stats = UserStats(ratedPlacesCount: 0, reviewedDishesCount: 0)
    @Published private(set) var categoryCount = 0
    @Published private(set) var placeReviews: [PlaceReview] = []
    @Published private(set) var dishReviews: [DishReview] = []
    @Published private(set) var placeNames: [UUID: String] = [:]
    @Published var editedHandle = ""
    @Published private(set) var editedHandleSuffix = ""
    @Published var editedDisplayName = ""
    @Published var editedBio = ""
    @Published var isLoading = false
    @Published var isSavingProfile = false
    @Published var errorMessage: String?

    private let logger = Logger(subsystem: "TrustMap", category: "ProfileViewModel")
    private let refreshCenter: AppRefreshCenter
    private let sessionStore: SessionStore
    private let userRepository: UserProfileRepository
    private let categoryRepository: CategoryRepository
    private let placeReviewRepository: PlaceReviewRepository
    private let dishReviewRepository: DishReviewRepository

    init(
        refreshCenter: AppRefreshCenter,
        sessionStore: SessionStore,
        userRepository: UserProfileRepository,
        categoryRepository: CategoryRepository,
        placeReviewRepository: PlaceReviewRepository,
        dishReviewRepository: DishReviewRepository
    ) {
        self.refreshCenter = refreshCenter
        self.sessionStore = sessionStore
        self.userRepository = userRepository
        self.categoryRepository = categoryRepository
        self.placeReviewRepository = placeReviewRepository
        self.dishReviewRepository = dishReviewRepository
        self.user = sessionStore.currentUser
    }

    func load() async {
        guard let currentUser = sessionStore.currentUser else {
            errorMessage = AppError.missingCurrentUser.errorDescription
            user = nil
            return
        }

        errorMessage = nil
        isLoading = true

        do {
            let currentProfile = try await userRepository.fetchCurrentUser()
            async let categories = categoryRepository.fetchMyCategories()
            async let placeReviews = placeReviewRepository.fetchReviews(authorUserID: currentUser.id)
            async let dishReviews = dishReviewRepository.fetchReviews(authorUserID: currentUser.id)

            let resolvedCategories = try await categories
            let resolvedPlaceReviews = try await placeReviews
            let resolvedDishReviews = try await dishReviews

            self.user = currentProfile
            self.categoryCount = resolvedCategories.count
            self.placeReviews = resolvedPlaceReviews
            self.dishReviews = resolvedDishReviews
            self.placeNames = (resolvedPlaceReviews.map { ($0.placeId, $0.place.name) }
                + resolvedDishReviews.map { ($0.placeId, $0.place.name) })
                .reduce(into: [:]) { partialResult, item in
                    partialResult[item.0] = item.1
                }
            self.stats = UserStats(
                ratedPlacesCount: Set(resolvedPlaceReviews.map(\.placeId)).count,
                reviewedDishesCount: resolvedDishReviews.count
            )
        } catch {
            logger.error("Unable to load profile: \(error.localizedDescription, privacy: .public)")
            errorMessage = AppError.wrap(error).errorDescription
        }

        isLoading = false
    }

    func deletePlaceReview(_ review: PlaceReview) async throws {
        try await placeReviewRepository.deleteReview(review)
        refreshCenter.invalidateAll()
        await load()
    }

    func deleteDishReview(_ review: DishReview) async throws {
        try await dishReviewRepository.deleteReview(review)
        refreshCenter.invalidateAll()
        await load()
    }

    func prepareProfileEditor() {
        guard let user = user ?? sessionStore.currentUser else {
            return
        }

        let components = Self.splitHandle(user.handle)
        editedHandle = components.base
        editedHandleSuffix = components.suffix
        editedDisplayName = user.displayName
        editedBio = user.bio ?? ""
    }

    func saveProfileChanges() async -> Bool {
        guard let currentUser = user ?? sessionStore.currentUser else {
            errorMessage = AppError.missingCurrentUser.errorDescription
            return false
        }

        isSavingProfile = true
        defer { isSavingProfile = false }

        do {
            let updatedUser = try await userRepository.updateCurrentUser(
                handle: editedHandle,
                displayName: editedDisplayName,
                bio: editedBio,
                avatarURL: currentUser.avatarURLString
            )
            user = updatedUser
            let components = Self.splitHandle(updatedUser.handle)
            editedHandle = components.base
            editedHandleSuffix = components.suffix
            sessionStore.updateCurrentUser(updatedUser)
            refreshCenter.invalidateAll()
            errorMessage = nil
            return true
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
            return false
        }
    }

    private static func splitHandle(_ handle: String) -> (base: String, suffix: String) {
        let parts = handle.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else {
            return (handle, "")
        }

        return (String(parts[0]), "#\(parts[1])")
    }
}
