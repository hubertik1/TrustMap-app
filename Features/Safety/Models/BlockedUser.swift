import Foundation

struct BlockedUser: Identifiable, Decodable, Sendable {
    let userId: UUID
    let handle: String
    let displayName: String
    let blockedAtUtc: Date

    var id: UUID { userId }
}
