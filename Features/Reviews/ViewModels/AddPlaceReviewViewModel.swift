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

    @Published var ratingOverall = 8
    @Published var descriptionText = ""
    @Published var visibility: VisibilityStatus = .friendsOnly
    @Published var availableCategories: [CustomCategory] = []
    @Published var selectedCategoryID: UUID?
    @Published var selectedPhotoData: [Data] = []
    @Published var selectedPreviewImages: [UIImage] = []
    @Published var isSaving = false
    @Published var isDeleting = false
    @Published var errorMessage: String?
    @Published var didSave = false
    @Published var didDelete = false
    @Published private(set) var isEditing = false
    @Published private(set) var lastAction: ReviewAction = .save

    let place: Place

    private let sessionStore: SessionStore
    private let categoryRepository: CategoryRepository
    private let placeReviewRepository: PlaceReviewRepository
    private var existingReview: PlaceReview?

    init(
        place: Place,
        sessionStore: SessionStore,
        categoryRepository: CategoryRepository,
        placeReviewRepository: PlaceReviewRepository,
        existingReview: PlaceReview? = nil
    ) {
        self.place = place
        self.sessionStore = sessionStore
        self.categoryRepository = categoryRepository
        self.placeReviewRepository = placeReviewRepository
        self.existingReview = existingReview
        self.isEditing = existingReview != nil

        if let existingReview {
            populateForm(with: existingReview)
        }
    }

    var navigationTitle: String {
        isEditing ? "Edit Place Review" : "Add Place Review"
    }

    func load() async {
        guard let currentUser = sessionStore.currentUser else {
            errorMessage = AppError.missingCurrentUser.errorDescription
            return
        }

        do {
            let defaultCategory = try categoryRepository.defaultRestaurantCategory(for: currentUser.id)
            availableCategories = try categoryRepository.categories(for: currentUser.id)

            if existingReview == nil {
                existingReview = try placeReviewRepository.review(for: place.id, authoredBy: currentUser.id)
            }

            if let existingReview {
                isEditing = true
                populateForm(with: existingReview)

                let placeCategoryIDs = Set(try categoryRepository.categories(forPlace: place.id).map(\.id))
                if let matchingCategory = availableCategories.first(where: { placeCategoryIDs.contains($0.id) }) {
                    selectedCategoryID = matchingCategory.id
                } else if selectedCategoryID == nil {
                    selectedCategoryID = defaultCategory.id
                }
            } else if selectedCategoryID == nil {
                selectedCategoryID = defaultCategory.id
            }
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
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

    func save() async {
        guard let currentUser = sessionStore.currentUser else {
            errorMessage = AppError.missingCurrentUser.errorDescription
            return
        }

        lastAction = .save
        isSaving = true
        errorMessage = nil

        do {
            let persistedReview = try placeReviewRepository.review(for: place.id, authoredBy: currentUser.id)
            let existingReview = persistedReview ?? self.existingReview
            let defaultCategoryID = try categoryRepository.defaultRestaurantCategory(for: currentUser.id).id
            let resolvedCategoryID = selectedCategoryID ?? defaultCategoryID

            let draft = PlaceReviewDraft(
                placeId: place.id,
                authorUserId: currentUser.id,
                ratingOverall: ratingOverall,
                reviewText: "",
                descriptionText: descriptionText,
                visibility: visibility,
                photoDataItems: selectedPhotoData,
                selectedCategoryId: resolvedCategoryID
            )

            if let existingReview {
                self.existingReview = try placeReviewRepository.updateReview(existingReview, with: draft)
                isEditing = true
            } else {
                self.existingReview = try placeReviewRepository.addReview(draft)
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
            guard let review = try placeReviewRepository.review(for: place.id, authoredBy: currentUser.id) ?? existingReview else {
                throw AppError.validationFailure("No review exists for this place yet.")
            }

            try placeReviewRepository.deleteReview(review)
            existingReview = nil
            didDelete = true
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
        }

        isDeleting = false
    }

    private func populateForm(with review: PlaceReview) {
        ratingOverall = review.ratingOverall
        descriptionText = review.descriptionText
        visibility = review.visibility
    }
}
