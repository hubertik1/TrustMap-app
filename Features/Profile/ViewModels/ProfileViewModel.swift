import Foundation
import OSLog

@MainActor
final class ProfileViewModel: ObservableObject {
    struct FriendsSummary: Equatable {
        var friendCount = 0
        var pendingRequestCount = 0
        var previewFriends: [UserSummary] = []

        var secondaryText: String {
            switch pendingRequestCount {
            case 1:
                return "1 pending request"
            case let count where count > 1:
                return "\(count) pending requests"
            default:
                return "Your trusted network"
            }
        }
    }

    @Published private(set) var user: User?
    @Published private(set) var stats = UserStats(ratedPlacesCount: 0, reviewedDishesCount: 0)
    @Published private(set) var categoryCount = 0
    @Published private(set) var placeReviews: [PlaceReview] = []
    @Published private(set) var dishReviews: [DishReview] = []
    @Published private(set) var placeNames: [UUID: String] = [:]
    @Published private(set) var friendsSummary = FriendsSummary()
    @Published var editedHandle = "" {
        didSet {
            let normalized = HandleComponents.normalizedEditableBase(from: editedHandle)
            if editedHandle != normalized {
                editedHandle = normalized
                return
            }

            if usernameErrorMessage != nil {
                usernameErrorMessage = nil
            }
        }
    }
    @Published private(set) var editedHandleSuffix = ""
    @Published var editedDisplayName = ""
    @Published var editedBio = ""
    @Published var isLoading = false
    @Published var isSavingProfile = false
    @Published var errorMessage: String?
    @Published var usernameErrorMessage: String?

    private let logger = Logger(subsystem: "TrustMap", category: "ProfileViewModel")
    private let refreshCenter: AppRefreshCenter
    private let sessionStore: SessionStore
    private let userRepository: UserProfileRepository
    private let friendRepository: FriendRepository
    private let categoryRepository: CategoryRepository
    private let placeReviewRepository: PlaceReviewRepository
    private let dishReviewRepository: DishReviewRepository

    init(
        refreshCenter: AppRefreshCenter,
        sessionStore: SessionStore,
        userRepository: UserProfileRepository,
        friendRepository: FriendRepository,
        categoryRepository: CategoryRepository,
        placeReviewRepository: PlaceReviewRepository,
        dishReviewRepository: DishReviewRepository
    ) {
        self.refreshCenter = refreshCenter
        self.sessionStore = sessionStore
        self.userRepository = userRepository
        self.friendRepository = friendRepository
        self.categoryRepository = categoryRepository
        self.placeReviewRepository = placeReviewRepository
        self.dishReviewRepository = dishReviewRepository
        self.user = sessionStore.currentUser
    }

    var canSaveProfile: Bool {
        guard let currentUser = user ?? sessionStore.currentUser else {
            return false
        }

        return !isSavingProfile
            && !normalizedEditedHandle.isEmpty
            && hasProfileChanges(comparedTo: currentUser)
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
            async let friendsSummary = loadFriendsSummary(fallbackFriendCount: currentProfile.friendCount)

            let resolvedCategories = try await categories
            let resolvedPlaceReviews = try await placeReviews
            let resolvedDishReviews = try await dishReviews
            let resolvedFriendsSummary = await friendsSummary

            self.user = currentProfile
            self.categoryCount = resolvedCategories.count
            self.placeReviews = resolvedPlaceReviews
            self.dishReviews = resolvedDishReviews
            self.friendsSummary = resolvedFriendsSummary
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

        errorMessage = nil
        usernameErrorMessage = nil
        let components = user.handleComponents
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

        let handle = normalizedEditedHandle
        guard !handle.isEmpty else {
            usernameErrorMessage = "Enter a username."
            errorMessage = nil
            return false
        }

        guard hasProfileChanges(comparedTo: currentUser) else {
            usernameErrorMessage = nil
            errorMessage = nil
            return false
        }

        errorMessage = nil
        usernameErrorMessage = nil
        isSavingProfile = true
        defer { isSavingProfile = false }

        do {
            let updatedUser = try await userRepository.updateCurrentUser(
                handle: handle,
                displayName: normalizedEditedDisplayName,
                bio: normalizedEditedBio,
                avatarURL: currentUser.avatarURLString
            )
            let resolvedUser = await refreshedUser(afterSaving: updatedUser)
            applyEditedProfile(resolvedUser)
            refreshCenter.invalidateAll()
            return true
        } catch {
            let wrappedError = AppError.wrap(error)
            if case .validationFailure(let message) = wrappedError,
               Self.isUsernameValidationError(message) {
                usernameErrorMessage = message
                errorMessage = nil
            } else {
                errorMessage = wrappedError.errorDescription
            }
            return false
        }
    }

    private var normalizedEditedHandle: String {
        HandleComponents.normalizedEditableBase(from: editedHandle)
    }

    private var normalizedEditedDisplayName: String {
        editedDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedEditedBio: String? {
        editedBio.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    private func hasProfileChanges(comparedTo currentUser: User) -> Bool {
        normalizedEditedHandle != currentUser.handleComponents.base
            || normalizedEditedDisplayName != currentUser.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            || normalizedEditedBio != currentUser.bio?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    private func refreshedUser(afterSaving fallbackUser: User) async -> User {
        do {
            return try await userRepository.fetchCurrentUser()
        } catch {
            logger.error("Unable to refresh profile after saving: \(error.localizedDescription, privacy: .public)")
            return fallbackUser
        }
    }

    private func applyEditedProfile(_ updatedUser: User) {
        user = updatedUser
        let components = updatedUser.handleComponents
        editedHandle = components.base
        editedHandleSuffix = components.suffix
        editedDisplayName = updatedUser.displayName
        editedBio = updatedUser.bio ?? ""
        sessionStore.updateCurrentUser(updatedUser)
        errorMessage = nil
        usernameErrorMessage = nil
    }

    private func loadFriendsSummary(fallbackFriendCount: Int) async -> FriendsSummary {
        do {
            async let friendsTask = friendRepository.fetchFriends()
            async let incomingRequestsTask = friendRepository.fetchIncomingRequests()

            let friends = try await friendsTask
            let incomingRequests = try await incomingRequestsTask

            return FriendsSummary(
                friendCount: friends.count,
                pendingRequestCount: incomingRequests.count,
                previewFriends: Array(friends.prefix(3).map(\.user))
            )
        } catch {
            logger.error("Unable to load friends summary: \(error.localizedDescription, privacy: .public)")
            return FriendsSummary(friendCount: fallbackFriendCount)
        }
    }

    private static func isUsernameValidationError(_ message: String) -> Bool {
        let normalized = message.lowercased()
        return normalized.contains("handle") || normalized.contains("username")
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
