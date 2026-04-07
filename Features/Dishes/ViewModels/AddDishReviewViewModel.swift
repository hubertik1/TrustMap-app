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
    @Published var dishRating = 4
    @Published var dishReviewText = ""
    @Published var priceText = ""
    @Published var visibility: VisibilityStatus = .friendsOnly
    @Published var selectedPhotoData: Data?
    @Published var selectedPreviewImage: UIImage?
    @Published private(set) var existingPhotos: [PhotoAsset] = []
    @Published private(set) var photoIDsMarkedForDeletion: Set<UUID> = []
    @Published var isSaving = false
    @Published var isDeleting = false
    @Published var errorMessage: String?
    @Published var didSave = false
    @Published var didDelete = false
    @Published private(set) var isEditing = false
    @Published private(set) var lastAction: ReviewAction = .save

    let place: Place

    private let dishReviewRepository: DishReviewRepository
    private let refreshCenter: AppRefreshCenter
    private var existingReview: DishReview?

    init(
        place: Place,
        dishReviewRepository: DishReviewRepository,
        refreshCenter: AppRefreshCenter,
        existingReview: DishReview? = nil,
        existingPhotoData: Data? = nil
    ) {
        self.place = place
        self.dishReviewRepository = dishReviewRepository
        self.refreshCenter = refreshCenter
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

    func removeSelectedPhoto() {
        selectedPhotoData = nil
        selectedPreviewImage = nil
    }

    func toggleExistingPhotoRemoval(_ photo: PhotoAsset) {
        if photoIDsMarkedForDeletion.contains(photo.id) {
            photoIDsMarkedForDeletion.remove(photo.id)
        } else {
            photoIDsMarkedForDeletion.insert(photo.id)
        }
    }

    func isExistingPhotoMarkedForRemoval(_ photo: PhotoAsset) -> Bool {
        photoIDsMarkedForDeletion.contains(photo.id)
    }

    func save() async {
        let trimmedDishName = dishName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDishName.isEmpty else {
            errorMessage = AppError.validationFailure("Enter a dish name.").errorDescription
            return
        }

        lastAction = .save
        isSaving = true
        errorMessage = nil

        do {
            let existingPlaceReviewID = existingReview?.placeReviewId

            let price = Double(priceText.replacingOccurrences(of: ",", with: "."))

            let draft = DishReviewDraft(
                placeId: place.id,
                placeReviewId: existingPlaceReviewID,
                visibility: visibility,
                dishName: trimmedDishName,
                dishRating: dishRating,
                dishReviewText: dishReviewText,
                price: price,
                photoData: selectedPhotoData,
                photoIDsToDelete: Array(photoIDsMarkedForDeletion)
            )

            if let existingReview {
                self.existingReview = try await dishReviewRepository.updateReview(existingReview, with: draft)
            } else {
                self.existingReview = try await dishReviewRepository.createReview(draft)
            }

            isEditing = true
            if let updatedReview = self.existingReview {
                populateForm(with: updatedReview)
            }
            refreshCenter.invalidateAll()
            didSave = true
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
        }

        isSaving = false
    }

    func deleteReview() async {
        lastAction = .delete

        isDeleting = true
        errorMessage = nil

        do {
            guard let reviewID = existingReview?.id else {
                throw AppError.validationFailure("No editable dish review exists for this place.")
            }

            let review = try await dishReviewRepository.fetchReview(id: reviewID)
            try await dishReviewRepository.deleteReview(review)
            existingReview = nil
            refreshCenter.invalidateAll()
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
        visibility = review.visibility
        existingPhotos = review.photos
        photoIDsMarkedForDeletion = []
        selectedPhotoData = nil
        selectedPreviewImage = nil
        if let price = review.price {
            priceText = String(price)
        } else {
            priceText = ""
        }
    }
}
