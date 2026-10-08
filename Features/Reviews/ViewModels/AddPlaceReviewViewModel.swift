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
                return L10n.unableToSaveReview
            case .delete:
                return L10n.unableToDeleteReview
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
        currentUserReviewVisibility: VisibilityStatus?,
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
        self.visibility = (currentUserReviewVisibility ?? preferencesStore.defaultPlaceReviewVisibility).selectableValue
        let editablePlaceName = place.customDisplayName ?? place.displayName
        self.customPlaceDisplayName = editablePlaceName
        self.editablePlaceNameBaseline = editablePlaceName

        if let existingReview {
            populateForm(with: existingReview)
        }
    }

    var navigationTitle: String {
        isEditing ? L10n.editPlaceReview : L10n.addPlaceReview
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

    var hasChanges: Bool {
        hasReviewChanges || hasCustomPlaceDisplayNameChange
    }

    var canSave: Bool {
        !isSaving
            && !isDeleting
            && isFormValid
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

            if availableCategories.isEmpty {
                availableCategories = resolvedCategories
            }

            place = resolvedPlaceDetails.place
            syncEditablePlaceNameInput()

            if let existingReview {
                populateForm(with: existingReview)
            } else {
                selectedCategoryId = resolvedCategorySelection(for: selectedCategoryId, isEditingReview: false)
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
            errorMessage = AppError.validationFailure(L10n.someSelectedPhotosCouldnTBePrepared).errorDescription
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
            errorMessage = AppError.validationFailure(L10n.chooseARating).errorDescription
            return
        }

        guard let selectedCategoryId else {
            errorMessage = AppError.validationFailure(L10n.chooseAnActiveCategory).errorDescription
            return
        }

        guard !isEditing || hasChanges else {
            didSave = true
            return
        }

        let shouldSaveReview = !isEditing || hasReviewChanges

        lastAction = .save
        isSaving = true
        errorMessage = nil

        do {
            try await saveCustomPlaceDisplayNameIfNeeded()

            if shouldSaveReview {
                let draft = PlaceReviewDraft(
                    placeId: place.id,
                    ratingOverall: ratingOverall,
                    reviewText: reviewTitleForSave,
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
            }

            refreshCenter.invalidateMapPin(placeID: place.id)
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
                throw AppError.validationFailure(L10n.noReviewExistsForThisPlaceYet)
            }

            try await placeReviewRepository.deleteReview(review)
            existingReview = nil
            refreshCenter.invalidateMapPin(placeID: place.id)
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
        selectedCategoryId = resolvedCategorySelection(for: review.categoryId, isEditingReview: true)
        existingPhotos = review.photos
        photoIDsMarkedForDeletion = []
        selectedPhotos = []
        syncEditablePlaceNameInput()
    }

    private var isFormValid: Bool {
        ratingOverall > 0 && selectedCategoryId != nil
    }

    private var hasReviewChanges: Bool {
        guard let existingReview else {
            return true
        }

        return ratingOverall != existingReview.ratingOverall
            || selectedCategoryId != existingReview.categoryId
            || visibility.selectableValue != existingReview.visibility.selectableValue
            || normalizedOptionalText(reviewTitleForSave) != normalizedOptionalText(existingReview.reviewText)
            || normalizedOptionalText(descriptionText) != normalizedOptionalText(existingReview.descriptionText)
            || !selectedPhotos.isEmpty
            || !photoIDsMarkedForDeletion.isEmpty
    }

    private var reviewTitleForSave: String {
        existingReview?.reviewText ?? ""
    }

    private var hasCustomPlaceDisplayNameChange: Bool {
        guard canEditCustomPlaceDisplayName else {
            return false
        }

        guard let currentDisplayName = normalizedCustomPlaceDisplayNameForSave else {
            return false
        }

        return currentDisplayName != editablePlaceNameBaseline.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedCustomPlaceDisplayNameForSave: String? {
        let trimmedDisplayName = customPlaceDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedDisplayName.isEmpty ? nil : trimmedDisplayName
    }

    private func normalizedOptionalText(_ value: String) -> String? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    private func defaultCategoryID(in categories: [CustomCategory]) -> UUID? {
        categories.first(where: \.isDefault)?.id ?? categories.first?.id
    }

    private func resolvedCategorySelection(for preferredCategoryId: UUID?, isEditingReview: Bool) -> UUID? {
        if let preferredCategoryId,
           availableCategories.contains(where: { $0.id == preferredCategoryId }) {
            return preferredCategoryId
        }

        if let selectedCategoryId,
           availableCategories.contains(where: { $0.id == selectedCategoryId }) {
            return selectedCategoryId
        }

        return isEditingReview ? nil : defaultCategoryID(in: availableCategories)
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
