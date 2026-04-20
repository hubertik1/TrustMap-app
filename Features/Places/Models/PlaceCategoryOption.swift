import Foundation

struct PlaceCategoryOption: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let categoryID: UUID?

    init(id: String, title: String, categoryID: UUID?) {
        self.id = id
        self.title = title
        self.categoryID = categoryID
    }

    static let all = PlaceCategoryOption(
        id: "all",
        title: "All Categories",
        categoryID: nil
    )

    static let restaurants = PlaceCategoryOption(
        id: TrustMapCategory.restaurantsCategoryID.uuidString,
        title: TrustMapCategory.restaurantsName,
        categoryID: TrustMapCategory.restaurantsCategoryID
    )

    init(category: CustomCategory) {
        self.id = category.id.uuidString
        self.title = category.name
        self.categoryID = category.id
    }

    func matches(categoryIDs: [UUID]) -> Bool {
        guard let categoryID else {
            return true
        }

        return categoryIDs.contains(categoryID)
    }
}
