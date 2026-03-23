import Foundation
import UIKit

@MainActor
final class AddDishReviewViewModel: ObservableObject {
    @Published var dishName = ""
    @Published var dishCategory = ""
    @Published var dishRating = 8
    @Published var dishReviewText = ""
    @Published var priceText = ""
    @Published var selectedPhotoData: Data?
    @Published var selectedPreviewImage: UIImage?
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var didSave = false

    let place: Place

    private let sessionStore: SessionStore
    private let placeReviewRepository: PlaceReviewRepository
    private let dishReviewRepository: DishReviewRepository

    init(
        place: Place,
        sessionStore: SessionStore,
        placeReviewRepository: PlaceReviewRepository,
        dishReviewRepository: DishReviewRepository
    ) {
        self.place = place
        self.sessionStore = sessionStore
        self.placeReviewRepository = placeReviewRepository
        self.dishReviewRepository = dishReviewRepository
    }

    func updateSelectedPhoto(with data: Data?) {
        guard let data else {
            selectedPhotoData = nil
            selectedPreviewImage = nil
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

        isSaving = true
        errorMessage = nil

        do {
            let existingPlaceReviewID = try placeReviewRepository
                .reviews(authoredBy: currentUser.id)
                .first(where: { $0.placeId == place.id })?
                .id

            let price = Double(priceText.replacingOccurrences(of: ",", with: "."))

            _ = try dishReviewRepository.addReview(
                DishReviewDraft(
                    placeId: place.id,
                    authorUserId: currentUser.id,
                    placeReviewId: existingPlaceReviewID,
                    dishName: trimmedDishName,
                    dishCategory: dishCategory.isEmpty ? nil : dishCategory,
                    dishRating: dishRating,
                    dishReviewText: dishReviewText,
                    price: price,
                    photoData: selectedPhotoData
                )
            )
            didSave = true
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
        }

        isSaving = false
    }
}
