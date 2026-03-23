import Foundation

struct PlaceCategoryOption: Identifiable, Hashable {
    let id: String
    let title: String
    let categoryID: UUID?

    static let restaurants = PlaceCategoryOption(
        id: "restaurants",
        title: "Restaurants",
        categoryID: nil
    )
}
