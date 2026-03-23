import Foundation
import UIKit

@MainActor
final class AddPlaceReviewViewModel: ObservableObject {
    @Published var ratingOverall = 8
    @Published var reviewText = ""
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
            availableCategories = try categoryRepository.categories(for: currentUser.id)
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
            _ = try placeReviewRepository.addReview(
                PlaceReviewDraft(
                    placeId: place.id,
                    authorUserId: currentUser.id,
                    ratingOverall: ratingOverall,
                    reviewText: reviewText,
                    descriptionText: descriptionText,
                    visibility: visibility,
                    photoDataItems: selectedPhotoData,
                    selectedCategoryId: selectedCategoryID,
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
