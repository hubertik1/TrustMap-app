import Foundation

struct PlaceCategoryOption: Identifiable, Hashable, Sendable {
    static let restaurantsCategoryID = UUID(uuidString: "D53A109F-9617-4A0A-B95A-5AD277A30764")!

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
        title: "All",
        categoryID: nil
    )

    static let restaurant = PlaceCategoryOption(
        id: restaurantsCategoryID.uuidString,
        title: "Restaurant",
        categoryID: restaurantsCategoryID
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
