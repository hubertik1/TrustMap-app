import Foundation
import UIKit

@MainActor
final class AddPlaceReviewViewModel: ObservableObject {
    @Published var ratingOverall = 8
    @Published var descriptionText = ""
    @Published var visibility: VisibilityStatus = .friendsOnly
    @Published var availableCategories: [CustomCategory] = []
    @Published var selectedCategoryID: UUID?
    @Published var newCategoryName = ""
    @Published var selectedPhotoData: [Data] = []
    @Published var selectedPreviewImages: [UIImage] = []
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var didSave = false
    @Published private(set) var isEditing = false

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

        isSaving = true
        errorMessage = nil

        do {
            let existingReview = try placeReviewRepository.review(for: place.id, authoredBy: currentUser.id) ?? existingReview
            let resolvedCategoryID: UUID?
            if let selectedCategoryID {
                resolvedCategoryID = selectedCategoryID
            } else if newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                resolvedCategoryID = try categoryRepository.defaultRestaurantCategory(for: currentUser.id).id
            } else {
                resolvedCategoryID = nil
            }

            let draft = PlaceReviewDraft(
                placeId: place.id,
                authorUserId: currentUser.id,
                ratingOverall: ratingOverall,
                reviewText: "",
                descriptionText: descriptionText,
                visibility: visibility,
                photoDataItems: selectedPhotoData,
                selectedCategoryId: resolvedCategoryID,
                newCategoryName: newCategoryName.isEmpty ? nil : newCategoryName
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

    private func populateForm(with review: PlaceReview) {
        ratingOverall = review.ratingOverall
        descriptionText = review.descriptionText
        visibility = review.visibility
    }
}
