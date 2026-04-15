import Foundation
import UIKit

@MainActor
final class AddPlaceReviewViewModel: ObservableObject {
    enum ReviewAction {
        case save
        case delete

        var errorTitle: String {
            switch self {
            case .save:
                return "Unable to Save Review"
            case .delete:
                return "Unable to Delete Review"
            }
        }
    }

    @Published var ratingOverall = 0
    @Published var descriptionText = ""
    @Published var visibility: VisibilityStatus = .friendsOnly
    @Published var selectedPhotoData: [Data] = []
    @Published var selectedPreviewImages: [UIImage] = []
    @Published private(set) var availableCategories: [CustomCategory] = []
    @Published var selectedCategoryId: UUID?
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

    private let placeReviewRepository: PlaceReviewRepository
    private let categoryRepository: CategoryRepository
    private let refreshCenter: AppRefreshCenter
    private var existingReview: PlaceReview?

    init(
        place: Place,
        placeReviewRepository: PlaceReviewRepository,
        categoryRepository: CategoryRepository,
        refreshCenter: AppRefreshCenter,
        preferencesStore: AppPreferencesStore,
        existingReview: PlaceReview? = nil
    ) {
        self.place = place
        self.placeReviewRepository = placeReviewRepository
        self.categoryRepository = categoryRepository
        self.refreshCenter = refreshCenter
        self.existingReview = existingReview
        self.isEditing = existingReview != nil
        self.visibility = preferencesStore.defaultPlaceReviewVisibility.selectableValue

        if let existingReview {
            populateForm(with: existingReview)
        }
    }

    var navigationTitle: String {
        isEditing ? "Edit Place Review" : "Add Place Review"
    }

    func load() async {
        if availableCategories.isEmpty {
            do {
                availableCategories = try await categoryRepository.fetchMyCategories()
                selectedCategoryId = existingReview?.categoryId ?? defaultCategoryID(in: availableCategories)
            } catch {
                errorMessage = AppError.wrap(error).errorDescription
            }
        }

        if let existingReview {
            populateForm(with: existingReview)
        }
    }

    func updateSelectedPhotos(with dataItems: [Data]) {
        var newData: [Data] = []
        var newImages: [UIImage] = []

        for data in dataItems {
            if let image = UIImage(data: data) {
                newData.append(data)
                newImages.append(image)
            }
        }

        selectedPhotoData = newData
        selectedPreviewImages = newImages
    }

    func removeSelectedPhoto(at index: Int) {
        guard selectedPreviewImages.indices.contains(index),
              selectedPhotoData.indices.contains(index) else {
            return
        }

        selectedPreviewImages.remove(at: index)
        selectedPhotoData.remove(at: index)
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
        guard ratingOverall > 0 else {
            errorMessage = AppError.validationFailure("Choose a rating.").errorDescription
            return
        }

        lastAction = .save
        isSaving = true
        errorMessage = nil

        do {
            let draft = PlaceReviewDraft(
                placeId: place.id,
                ratingOverall: ratingOverall,
                reviewText: "",
                descriptionText: descriptionText,
                visibility: visibility.selectableValue,
                photoDataItems: selectedPhotoData,
                photoIDsToDelete: Array(photoIDsMarkedForDeletion),
                selectedCategoryId: selectedCategoryId
            )

            if let existingReview {
                self.existingReview = try await placeReviewRepository.updateReview(existingReview, with: draft)
            } else {
                self.existingReview = try await placeReviewRepository.createReview(draft)
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
            guard let review = existingReview else {
                throw AppError.validationFailure("No review exists for this place yet.")
            }

            try await placeReviewRepository.deleteReview(review)
            existingReview = nil
            refreshCenter.invalidateAll()
            didDelete = true
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
        }

        isDeleting = false
    }

    private func populateForm(with review: PlaceReview) {
        ratingOverall = review.ratingOverall
        descriptionText = review.descriptionText
        visibility = review.visibility.selectableValue
        selectedCategoryId = review.categoryId ?? selectedCategoryId ?? defaultCategoryID(in: availableCategories)
        existingPhotos = review.photos
        photoIDsMarkedForDeletion = []
        selectedPhotoData = []
        selectedPreviewImages = []
    }

    private func defaultCategoryID(in categories: [CustomCategory]) -> UUID? {
        categories.first(where: \.isDefault)?.id ?? categories.first?.id
    }
}
