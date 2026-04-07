import Foundation

enum RelationshipStatus: String, Codable, Sendable {
    case friends = "Friends"
    case incomingRequest = "IncomingRequest"
    case none = "None"
    case outgoingRequest = "OutgoingRequest"
    case `self` = "Self"
}

struct UserSummary: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let handle: String
    let displayName: String
    let avatarURLString: String?

    enum CodingKeys: String, CodingKey {
        case avatarURLString = "avatarUrl"
        case displayName
        case handle
        case id
    }

    var avatarURL: URL? {
        AppConfiguration.resolvedBackendURL(from: avatarURLString)
    }
}

struct User: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let handle: String
    let displayName: String
    let bio: String?
    let avatarURLString: String?
    let relationshipStatus: RelationshipStatus
    let friendCount: Int
    let visiblePlaceReviewCount: Int
    let visibleDishReviewCount: Int
    let isMe: Bool

    enum CodingKeys: String, CodingKey {
        case avatarURLString = "avatarUrl"
        case bio
        case displayName
        case friendCount
        case handle
        case id
        case isMe
        case relationshipStatus
        case visibleDishReviewCount
        case visiblePlaceReviewCount
    }

    var avatarURL: URL? {
        AppConfiguration.resolvedBackendURL(from: avatarURLString)
    }

    var summary: UserSummary {
        UserSummary(
            id: id,
            handle: handle,
            displayName: displayName,
            avatarURLString: avatarURLString
        )
    }

    init(
        id: UUID,
        handle: String,
        displayName: String,
        bio: String? = nil,
        avatarURLString: String? = nil,
        relationshipStatus: RelationshipStatus = .self,
        friendCount: Int = 0,
        visiblePlaceReviewCount: Int = 0,
        visibleDishReviewCount: Int = 0,
        isMe: Bool = false
    ) {
        self.id = id
        self.handle = handle
        self.displayName = displayName
        self.bio = bio
        self.avatarURLString = avatarURLString
        self.relationshipStatus = relationshipStatus
        self.friendCount = friendCount
        self.visiblePlaceReviewCount = visiblePlaceReviewCount
        self.visibleDishReviewCount = visibleDishReviewCount
        self.isMe = isMe
    }
}

struct UserSearchResult: Identifiable, Codable, Hashable, Sendable {
    let user: UserSummary
    let relationshipStatus: RelationshipStatus

    var id: UUID {
        user.id
    }
}
