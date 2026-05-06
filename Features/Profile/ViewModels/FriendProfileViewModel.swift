import Foundation

@MainActor
final class FriendProfileViewModel: ObservableObject {
    @Published private(set) var user: User?
    @Published private(set) var placeReviews: [PlaceReview] = []
    @Published private(set) var dishReviews: [DishReview] = []
    @Published private(set) var placeNames: [UUID: String] = [:]
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var reviewsErrorMessage: String?

    private let userID: UUID
    private let userRepository: UserProfileRepository
    private let placeReviewRepository: PlaceReviewRepository
    private let dishReviewRepository: DishReviewRepository

    init(
        userID: UUID,
        initialUser: UserSummary?,
        userRepository: UserProfileRepository,
        placeReviewRepository: PlaceReviewRepository,
        dishReviewRepository: DishReviewRepository
    ) {
        self.userID = userID
        self.userRepository = userRepository
        self.placeReviewRepository = placeReviewRepository
        self.dishReviewRepository = dishReviewRepository

        if let initialUser {
            user = User(
                id: initialUser.id,
                handle: initialUser.handle,
                displayName: initialUser.displayName,
                avatarURLString: initialUser.avatarURLString,
                relationshipStatus: .none,
                isMe: false
            )
        }
    }

    func load() async {
        errorMessage = nil
        reviewsErrorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let loadedUser = try await userRepository.fetchUser(id: userID)
            user = loadedUser
            guard loadedUser.canViewProfile else {
                placeReviews = []
                dishReviews = []
                placeNames = [:]
                return
            }
        } catch {
            guard !Self.isCancellation(error) else { return }
            errorMessage = AppError.wrap(error).errorDescription
            return
        }

        do {
            async let placeReviews = placeReviewRepository.fetchReviews(authorUserID: userID)
            async let dishReviews = dishReviewRepository.fetchReviews(authorUserID: userID)

            let resolvedPlaceReviews = try await placeReviews
            let resolvedDishReviews = try await dishReviews

            self.placeReviews = resolvedPlaceReviews
            self.dishReviews = resolvedDishReviews
            self.placeNames = (resolvedPlaceReviews.map { ($0.placeId, $0.place.displayName) }
                + resolvedDishReviews.map { ($0.placeId, $0.place.displayName) })
                .reduce(into: [:]) { partialResult, item in
                    partialResult[item.0] = item.1
                }
        } catch {
            guard !Self.isCancellation(error) else { return }
            reviewsErrorMessage = AppError.wrap(error).errorDescription
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
