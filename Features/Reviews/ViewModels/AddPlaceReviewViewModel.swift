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

    let place: Place

    private let sessionStore: SessionStore
    private let categoryRepository: CategoryRepository
    private let placeReviewRepository: PlaceReviewRepository

    init(
        place: Place,
        sessionStore: SessionStore,
        categoryRepository: CategoryRepository,
        placeReviewRepository: PlaceReviewRepository
    ) {
        self.place = place
        self.sessionStore = sessionStore
        self.categoryRepository = categoryRepository
        self.placeReviewRepository = placeReviewRepository
    }

    func loadCategories() async {
        guard let currentUser = sessionStore.currentUser else {
            errorMessage = AppError.missingCurrentUser.errorDescription
            return
        }

        do {
            let defaultCategory = try categoryRepository.defaultRestaurantCategory(for: currentUser.id)
            availableCategories = try categoryRepository.categories(for: currentUser.id)

            if selectedCategoryID == nil {
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
            let resolvedCategoryID: UUID?
            if let selectedCategoryID {
                resolvedCategoryID = selectedCategoryID
            } else if newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                resolvedCategoryID = try categoryRepository.defaultRestaurantCategory(for: currentUser.id).id
            } else {
                resolvedCategoryID = nil
            }

            _ = try placeReviewRepository.addReview(
                PlaceReviewDraft(
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
            )
            didSave = true
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
        }

        isSaving = false
    }
}
