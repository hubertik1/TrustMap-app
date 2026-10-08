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
                return L10n.unableToSaveDishReview
            case .delete:
                return L10n.unableToDeleteDishReview
            }
        }
    }

    @Published var dishName = ""
    @Published var dishRating = 0
    @Published var dishReviewText = ""
    @Published var priceText = ""
    @Published var visibility: VisibilityStatus = .friendsOnly
    @Published private(set) var selectedPhoto: SelectedPhotoUpload?
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

    private let placeReviewID: UUID?
    private let dishReviewRepository: DishReviewRepository
    private let categoryRepository: CategoryRepository
    private let refreshCenter: AppRefreshCenter
    private var existingReview: DishReview?

    init(
        place: Place,
        placeReviewID: UUID? = nil,
        dishReviewRepository: DishReviewRepository,
        categoryRepository: CategoryRepository,
        refreshCenter: AppRefreshCenter,
        preferencesStore: AppPreferencesStore,
        currentUserReviewVisibility: VisibilityStatus?,
        existingReview: DishReview? = nil,
        existingPhotoData: Data? = nil
    ) {
        self.place = place
        self.placeReviewID = placeReviewID
        self.dishReviewRepository = dishReviewRepository
        self.categoryRepository = categoryRepository
        self.refreshCenter = refreshCenter
        self.existingReview = existingReview
        self.isEditing = existingReview != nil
        self.visibility = (currentUserReviewVisibility ?? preferencesStore.defaultDishReviewVisibility).selectableValue

        if let existingReview {
            populateForm(with: existingReview)
        }

        if let existingPhotoData, let image = UIImage(data: existingPhotoData) {
            selectedPhoto = SelectedPhotoUpload(uploadData: existingPhotoData, previewImage: image)
        }
    }

    var navigationTitle: String {
        isEditing ? L10n.editDishReview : L10n.addDishReview
    }

    var selectedPhotoData: Data? {
        selectedPhoto?.uploadData
    }

    var selectedPreviewImage: UIImage? {
        selectedPhoto?.previewImage
    }

    var hasChanges: Bool {
        hasReviewChanges
    }

    var canSave: Bool {
        !isSaving
            && !isDeleting
            && isFormValid
    }

    func load() async {
        if availableCategories.isEmpty {
            do {
                let categories = try await categoryRepository.fetchMyCategories()
                availableCategories = categories.filter { category in
                    category.id == TrustMapCategory.restaurantsCategoryID
                }
                if let existingReview {
                    selectedCategoryId = resolvedCategorySelection(for: existingReview.categoryId, isEditingReview: true)
                } else {
                    selectedCategoryId = resolvedCategorySelection(for: selectedCategoryId, isEditingReview: false)
                }
            } catch {
                errorMessage = AppError.wrap(error).errorDescription
            }
        }

        if let existingReview {
            populateForm(with: existingReview)
        }
    }

    func setSelectedPhoto(_ photo: SelectedPhotoUpload?) {
        selectedPhoto = photo
        errorMessage = nil
    }

    func showPhotoPreparationFailure() {
        errorMessage = AppError.validationFailure(L10n.theSelectedPhotoCouldnTBePrepared).errorDescription
    }

    func removeSelectedPhoto() {
        selectedPhoto = nil
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
            errorMessage = AppError.validationFailure(L10n.enterADishName).errorDescription
            return
        }

        guard dishRating > 0 else {
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

        lastAction = .save
        isSaving = true
        errorMessage = nil

        do {
            let existingPlaceReviewID = existingReview?.placeReviewId ?? placeReviewID

            let price = normalizedPriceForSave
            var photoIDsToDelete = photoIDsMarkedForDeletion
            if selectedPhoto != nil {
                photoIDsToDelete.formUnion(existingPhotos.map(\.id))
            }

            let draft = DishReviewDraft(
                placeId: place.id,
                placeReviewId: existingPlaceReviewID,
                visibility: visibility.selectableValue,
                dishName: trimmedDishName,
                dishRating: dishRating,
                dishReviewText: dishReviewText,
                price: price,
                photoData: selectedPhotoData,
                photoIDsToDelete: Array(photoIDsToDelete),
                selectedCategoryId: selectedCategoryId
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
            guard let reviewID = existingReview?.id else {
                throw AppError.validationFailure(L10n.noEditableDishReviewExistsForThisPlace)
            }

            let review = try await dishReviewRepository.fetchReview(id: reviewID)
            try await dishReviewRepository.deleteReview(review)
            existingReview = nil
            refreshCenter.invalidateMapPin(placeID: place.id)
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
        visibility = review.visibility.selectableValue
        selectedCategoryId = resolvedCategorySelection(for: review.categoryId, isEditingReview: true)
        existingPhotos = review.photos
        photoIDsMarkedForDeletion = []
        selectedPhoto = nil
        if let price = review.price {
            priceText = String(price)
        } else {
            priceText = ""
        }
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

    private var isFormValid: Bool {
        !normalizedDishName.isEmpty
            && dishRating > 0
            && selectedCategoryId != nil
    }

    private var hasReviewChanges: Bool {
        guard let existingReview else {
            return true
        }

        return normalizedDishName != existingReview.dishName.trimmingCharacters(in: .whitespacesAndNewlines)
            || dishRating != existingReview.dishRating
            || selectedCategoryId != existingReview.categoryId
            || visibility.selectableValue != existingReview.visibility.selectableValue
            || normalizedOptionalText(dishReviewText) != normalizedOptionalText(existingReview.dishReviewText)
            || normalizedPriceForSave != existingReview.price
            || normalizedCurrencyCode(currencyCodeForSave) != normalizedCurrencyCode(existingReview.currencyCode)
            || selectedPhoto != nil
            || !photoIDsMarkedForDeletion.isEmpty
    }

    private var normalizedDishName: String {
        dishName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedPriceForSave: Double? {
        let normalizedText = priceText
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(normalizedText)
    }

    private var currencyCodeForSave: String? {
        normalizedPriceForSave == nil ? nil : Locale.current.currency?.identifier
    }

    private func normalizedOptionalText(_ value: String) -> String? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    private func normalizedCurrencyCode(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue.uppercased()
    }
}
