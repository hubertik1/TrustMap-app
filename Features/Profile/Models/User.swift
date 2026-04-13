import Foundation

enum RelationshipStatus: String, Codable, Sendable {
    case friends = "Friends"
    case incomingRequest = "IncomingRequest"
    case none = "None"
    case outgoingRequest = "OutgoingRequest"
    case `self` = "Self"
}

struct HandleComponents: Hashable, Sendable {
    let base: String
    let suffix: String

    init(handle: String) {
        let trimmed = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)

        if parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty {
            base = String(parts[0])
            suffix = "#\(parts[1])"
        } else {
            base = trimmed
            suffix = ""
        }
    }

    static func normalizedEditableBase(from input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutAtPrefix = trimmed.drop(while: { $0 == "@" })
        let base = withoutAtPrefix.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first
        return String(base ?? Substring()).trimmingCharacters(in: .whitespacesAndNewlines)
    }
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

extension UserSummary {
    var handleComponents: HandleComponents {
        HandleComponents(handle: handle)
    }
}

extension User {
    var handleComponents: HandleComponents {
        HandleComponents(handle: handle)
    }
}
