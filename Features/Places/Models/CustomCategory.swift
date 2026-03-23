import Foundation
import SwiftData

@Model
final class CustomCategory {
    var id: UUID
    var ownerUserId: UUID
    var name: String
    var iconName: String?
    var createdAt: Date

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
