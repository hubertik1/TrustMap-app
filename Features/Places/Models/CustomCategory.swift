import Foundation

struct CustomCategory: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let ownerUserId: UUID
    let name: String
    let iconName: String?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        ownerUserId: UUID,
        name: String,
        iconName: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.ownerUserId = ownerUserId
        self.name = name
        self.iconName = iconName
        self.createdAt = createdAt
    }
}
