import Foundation

struct CustomCategory: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let ownerUserId: UUID?
    let owner: UserSummary?
    let name: String
    let iconName: String?
    let isDefault: Bool
    let isOwnedByCurrentUser: Bool
    let createdAt: Date

    private enum CodingKeys: String, CodingKey {
        case id
        case ownerUserId
        case owner
        case name
        case iconName
        case isDefault
        case isOwnedByCurrentUser
        case createdAt = "createdAtUtc"
    }

    init(
        id: UUID = UUID(),
        ownerUserId: UUID?,
        owner: UserSummary? = nil,
        name: String,
        iconName: String? = nil,
        isDefault: Bool = false,
        isOwnedByCurrentUser: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.ownerUserId = ownerUserId
        self.owner = owner
        self.name = name
        self.iconName = iconName
        self.isDefault = isDefault
        self.isOwnedByCurrentUser = isOwnedByCurrentUser
        self.createdAt = createdAt
    }
}
