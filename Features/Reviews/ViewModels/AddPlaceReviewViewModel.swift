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
    @Published private(set) var selectedPhotos: [SelectedPhotoUpload] = []
    @Published private(set) var availableCategories: [CustomCategory] = []
    @Published var selectedCategoryId: UUID?
    @Published private(set) var existingPhotos: [PhotoAsset] = []
    @Published private(set) var photoIDsMarkedForDeletion: Set<UUID> = []
    @Published var customPlaceDisplayName = ""
    @Published var isSaving = false
    @Published var isDeleting = false
    @Published var errorMessage: String?
    @Published var didSave = false
    @Published var didDelete = false
    @Published private(set) var isEditing = false
    @Published private(set) var lastAction: ReviewAction = .save

    @Published private(set) var place: Place

    private let currentUserID: UUID?
    private let placeRepository: PlaceRepository
    private let placeReviewRepository: PlaceReviewRepository
    private let categoryRepository: CategoryRepository
    private let refreshCenter: AppRefreshCenter
    private let provisionalCanEditCustomPlaceDisplayName: Bool
    private var existingReview: PlaceReview?
    private var editablePlaceNameBaseline: String

    init(
        place: Place,
        currentUserID: UUID?,
        placeRepository: PlaceRepository,
        placeReviewRepository: PlaceReviewRepository,
        categoryRepository: CategoryRepository,
        refreshCenter: AppRefreshCenter,
        preferencesStore: AppPreferencesStore,
        existingReview: PlaceReview? = nil
    ) {
        self.place = place
        self.currentUserID = currentUserID
        self.placeRepository = placeRepository
        self.placeReviewRepository = placeReviewRepository
        self.categoryRepository = categoryRepository
        self.refreshCenter = refreshCenter
        self.provisionalCanEditCustomPlaceDisplayName =
            place.isCustomPin && (place.createdByUserId == currentUserID || place.createdByUserId == nil)
        self.existingReview = existingReview
        self.isEditing = existingReview != nil
        self.visibility = preferencesStore.defaultPlaceReviewVisibility.selectableValue
        let editablePlaceName = place.customDisplayName ?? place.displayName
        self.customPlaceDisplayName = editablePlaceName
        self.editablePlaceNameBaseline = editablePlaceName

        if let existingReview {
            populateForm(with: existingReview)
        }
    }

    var navigationTitle: String {
        isEditing ? "Edit Place Review" : "Add Place Review"
    }

    var selectedPhotoData: [Data] {
        selectedPhotos.map(\.uploadData)
    }

    var selectedPreviewImages: [UIImage] {
        selectedPhotos.map(\.previewImage)
    }

    var canEditCustomPlaceDisplayName: Bool {
        place.canRenameCustomDisplayName(as: currentUserID) || provisionalCanEditCustomPlaceDisplayName
    }

    var placeAddressLine: String? {
        let trimmedAddress = place.address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAddress.isEmpty else {
            return nil
        }

        let trimmedSubtitle = place.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedSubtitle.isEmpty ? trimmedAddress : trimmedSubtitle
    }

    func load() async {
        do {
            async let categoriesTask: [CustomCategory] = availableCategories.isEmpty
                ? categoryRepository.fetchMyCategories()
                : availableCategories
            async let placeDetailsTask = placeRepository.fetchPlaceDetails(id: place.id)

            let (resolvedCategories, resolvedPlaceDetails) = try await (categoriesTask, placeDetailsTask)
            let restaurantsOnlyCategories = resolvedCategories.filter { category in
                category.id == TrustMapCategory.restaurantsCategoryID
            }

            if availableCategories.isEmpty {
                availableCategories = restaurantsOnlyCategories
            }

            place = resolvedPlaceDetails.place
            syncEditablePlaceNameInput()
            selectedCategoryId = existingReview?.categoryId ?? selectedCategoryId ?? defaultCategoryID(in: availableCategories)

            if let existingReview {
                populateForm(with: existingReview)
            }
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
        }
    }

    func appendSelectedPhotos(_ photos: [SelectedPhotoUpload], didSkipAnyPhotos: Bool) {
        guard !photos.isEmpty || didSkipAnyPhotos else {
            return
        }

        selectedPhotos.append(contentsOf: photos)
        if didSkipAnyPhotos {
            errorMessage = AppError.validationFailure("Some selected photos couldn't be prepared.").errorDescription
        } else {
            errorMessage = nil
        }
    }

    func removeSelectedPhoto(at index: Int) {
        guard selectedPhotos.indices.contains(index) else {
            return
        }

        selectedPhotos.remove(at: index)
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
            try await saveCustomPlaceDisplayNameIfNeeded()

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
        selectedPhotos = []
        syncEditablePlaceNameInput()
    }

    private func defaultCategoryID(in categories: [CustomCategory]) -> UUID? {
        categories.first(where: \.isDefault)?.id ?? categories.first?.id
    }

    private func saveCustomPlaceDisplayNameIfNeeded() async throws {
        guard canEditCustomPlaceDisplayName else {
            return
        }

        let trimmedDisplayName = customPlaceDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let baselineDisplayName = editablePlaceNameBaseline.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedDisplayName.isEmpty, trimmedDisplayName != baselineDisplayName else {
            return
        }

        let updatedPlace = try await placeRepository.updateCustomDisplayName(
            placeID: place.id,
            displayName: trimmedDisplayName
        )
        place = updatedPlace
        syncEditablePlaceNameInput()
    }

    private func syncEditablePlaceNameInput() {
        let editablePlaceName = place.customDisplayName ?? place.displayName
        customPlaceDisplayName = editablePlaceName
        editablePlaceNameBaseline = editablePlaceName
    }
}
