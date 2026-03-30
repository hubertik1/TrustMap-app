import Foundation
import SwiftData

@Model
final class User {
    var id: UUID
    var appleUserId: String
    var displayName: String
    var avatarReference: String?
    var bio: String?
    var cloudKitUserRecordName: String?
    var sharedContentShareRecordName: String?
    var sharedContentShareURL: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        appleUserId: String,
        displayName: String,
        avatarReference: String? = nil,
        bio: String? = nil,
        cloudKitUserRecordName: String? = nil,
        sharedContentShareRecordName: String? = nil,
        sharedContentShareURL: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.appleUserId = appleUserId
        self.displayName = displayName
        self.avatarReference = avatarReference
        self.bio = bio
        self.cloudKitUserRecordName = cloudKitUserRecordName
        self.sharedContentShareRecordName = sharedContentShareRecordName
        self.sharedContentShareURL = sharedContentShareURL
        self.createdAt = createdAt
    }
}
