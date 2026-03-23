import Foundation
import SwiftData

@Model
final class PlaceCategoryAssignment {
    var id: UUID
    var placeId: UUID
    var categoryId: UUID
    var assignedByUserId: UUID

    init(
        id: UUID = UUID(),
        placeId: UUID,
        categoryId: UUID,
        assignedByUserId: UUID
    ) {
        self.id = id
        self.placeId = placeId
        self.categoryId = categoryId
        self.assignedByUserId = assignedByUserId
    }
}
