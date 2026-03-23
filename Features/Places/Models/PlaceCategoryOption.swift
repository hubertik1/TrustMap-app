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
        title: "All",
        categoryID: nil
    )

    static let restaurants = PlaceCategoryOption(
        id: "restaurants",
        title: "Restaurants",
        categoryID: nil
    )

    init(category: CustomCategory) {
        self.id = category.id.uuidString
        self.title = category.name
        self.categoryID = category.id
    }

    func matches(categoryNames: [String]) -> Bool {
        if self == .all {
            return true
        }

        if self == .restaurants {
            return categoryNames.isEmpty || categoryNames.contains {
                $0.caseInsensitiveCompare(Self.restaurants.title) == .orderedSame
            }
        }

        return categoryNames.contains {
            $0.caseInsensitiveCompare(title) == .orderedSame
        }
    }
}
