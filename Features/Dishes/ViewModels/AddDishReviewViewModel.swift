import Foundation
import UIKit

@MainActor
final class AddDishReviewViewModel: ObservableObject {
    enum ReviewAction {
        case save
        case delete

        var errorTitle: String {
            switch self {
            case .save:
                return "Unable to Save Dish Review"
            case .delete:
                return "Unable to Delete Dish Review"
            }
        }
    }

    @Published var dishName = ""
    @Published var dishRating = 8
    @Published var dishReviewText = ""
    @Published var priceText = ""
    @Published var selectedPhotoData: Data?
    @Published var selectedPreviewImage: UIImage?
    @Published var isSaving = false
    @Published var isDeleting = false
    @Published var errorMessage: String?
    @Published var didSave = false
    @Published var didDelete = false
    @Published private(set) var isEditing = false
    @Published private(set) var lastAction: ReviewAction = .save

    let place: Place

    private let sessionStore: SessionStore
    private let placeReviewRepository: PlaceReviewRepository
    private let dishReviewRepository: DishReviewRepository
    private var existingReview: DishReview?

    init(
        place: Place,
        sessionStore: SessionStore,
        placeReviewRepository: PlaceReviewRepository,
        dishReviewRepository: DishReviewRepository,
        existingReview: DishReview? = nil,
        existingPhotoData: Data? = nil
    ) {
        self.place = place
        self.sessionStore = sessionStore
        self.placeReviewRepository = placeReviewRepository
        self.dishReviewRepository = dishReviewRepository
        self.existingReview = existingReview
        self.isEditing = existingReview != nil

        if let existingReview {
            populateForm(with: existingReview)
        }

        if let existingPhotoData, let image = UIImage(data: existingPhotoData) {
            selectedPreviewImage = image
        }
    }

    var navigationTitle: String {
        isEditing ? "Edit Dish Review" : "Add Dish Review"
    }

    func updateSelectedPhoto(with data: Data?) {
        guard let data else {
            return
        }

        if let image = UIImage(data: data) {
            selectedPhotoData = data
            selectedPreviewImage = image
        }
    }

    func save() async {
        guard let currentUser = sessionStore.currentUser else {
            errorMessage = AppError.missingCurrentUser.errorDescription
            return
        }

        let trimmedDishName = dishName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDishName.isEmpty else {
            errorMessage = AppError.validationFailure("Enter a dish name.").errorDescription
            return
        }

        lastAction = .save
        isSaving = true
        errorMessage = nil

        do {
            let existingPlaceReviewID = try placeReviewRepository
                .reviews(authoredBy: currentUser.id)
                .first(where: { $0.placeId == place.id })?
                .id

            let price = Double(priceText.replacingOccurrences(of: ",", with: "."))

            let draft = DishReviewDraft(
                placeId: place.id,
                authorUserId: currentUser.id,
                placeReviewId: existingPlaceReviewID,
                visibility: resolvedVisibility(currentUserID: currentUser.id),
                dishName: trimmedDishName,
                dishRating: dishRating,
                dishReviewText: dishReviewText,
                price: price,
                photoData: selectedPhotoData
            )

            let persistedReview = try existingReview.map { try dishReviewRepository.review(withID: $0.id) } ?? nil
            let resolvedExistingReview = persistedReview ?? existingReview

            if let resolvedExistingReview {
                existingReview = try dishReviewRepository.updateReview(resolvedExistingReview, with: draft)
                isEditing = true
            } else {
                existingReview = try dishReviewRepository.addReview(draft)
                isEditing = true
            }

            didSave = true
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
        }

        isSaving = false
    }

    func deleteReview() async {
        lastAction = .delete

        guard let currentUser = sessionStore.currentUser else {
            errorMessage = AppError.missingCurrentUser.errorDescription
            return
        }

        isDeleting = true
        errorMessage = nil

        do {
            guard let reviewID = existingReview?.id else {
                throw AppError.validationFailure("No editable dish review exists for this place.")
            }

            guard let review = try dishReviewRepository.review(withID: reviewID),
                  review.authorUserId == currentUser.id else {
                throw AppError.validationFailure("No editable dish review exists for this place.")
            }

            try dishReviewRepository.deleteReview(review)
            existingReview = nil
            didDelete = true
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
        }

        isDeleting = false
    }

    private func populateForm(with review: DishReview) {
        dishName = review.dishName
        dishRating = review.dishRating
        dishReviewText = review.dishReviewText
        if let price = review.price {
            priceText = String(price)
        }
    }

    private func resolvedVisibility(currentUserID: UUID) -> VisibilityStatus {
        if let existingReview {
            return existingReview.visibility
        }

        if let review = try? placeReviewRepository.reviews(authoredBy: currentUserID).first(where: { $0.placeId == place.id }) {
            return review.visibility
        }

        return .friendsOnly
    }
}
