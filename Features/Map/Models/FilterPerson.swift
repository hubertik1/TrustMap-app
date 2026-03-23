import Foundation

struct FilterPerson: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let isCurrentUser: Bool
}
