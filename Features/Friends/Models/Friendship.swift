import Foundation

struct Friendship: Identifiable, Hashable, Sendable {
    let id: UUID
    let user: UserSummary
    let createdAt: Date

    init(
        id: UUID = UUID(),
        user: UserSummary,
        createdAt: Date = .now
    ) {
        self.id = id
        self.user = user
        self.createdAt = createdAt
    }
}
