import Foundation

struct PlaceCategoryAssignment: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let placeId: UUID
    let categoryId: UUID
    let assignedByUserId: UUID

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
