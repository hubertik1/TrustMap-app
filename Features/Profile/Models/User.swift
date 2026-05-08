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

struct User: Identifiable, Decodable, Hashable, Sendable {
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
    let reviewVisibility: VisibilityStatus
    let friendListVisibility: VisibilityStatus
    let profileVisibility: VisibilityStatus
    let profilePictureVisibility: VisibilityStatus
    let canViewProfile: Bool
    let canViewFriends: Bool
    let canViewReviews: Bool
    let canViewProfilePicture: Bool
    let supportsPrivacySettings: Bool

    enum CodingKeys: String, CodingKey {
        case avatarURLString = "avatarUrl"
        case bio
        case canViewProfile
        case canViewFriends
        case canViewReviews
        case canViewProfilePicture
        case displayName
        case friendCount
        case friendListVisibility
        case handle
        case id
        case isMe
        case profilePictureVisibility
        case profileVisibility
        case relationshipStatus
        case reviewVisibility
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
        isMe: Bool = false,
        reviewVisibility: VisibilityStatus = .friendsOnly,
        friendListVisibility: VisibilityStatus = .friendsOnly,
        profileVisibility: VisibilityStatus = .public,
        profilePictureVisibility: VisibilityStatus = .public,
        canViewProfile: Bool = true,
        canViewFriends: Bool = true,
        canViewReviews: Bool = true,
        canViewProfilePicture: Bool = true,
        supportsPrivacySettings: Bool = true
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
        self.reviewVisibility = reviewVisibility
        self.friendListVisibility = friendListVisibility
        self.profileVisibility = profileVisibility
        self.profilePictureVisibility = profilePictureVisibility
        self.canViewProfile = canViewProfile
        self.canViewFriends = canViewFriends
        self.canViewReviews = canViewReviews
        self.canViewProfilePicture = canViewProfilePicture
        self.supportsPrivacySettings = supportsPrivacySettings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        handle = try container.decode(String.self, forKey: .handle)
        displayName = try container.decode(String.self, forKey: .displayName)
        bio = try container.decodeIfPresent(String.self, forKey: .bio)
        avatarURLString = try container.decodeIfPresent(String.self, forKey: .avatarURLString)
        relationshipStatus = try container.decode(RelationshipStatus.self, forKey: .relationshipStatus)
        friendCount = try container.decode(Int.self, forKey: .friendCount)
        visiblePlaceReviewCount = try container.decode(Int.self, forKey: .visiblePlaceReviewCount)
        visibleDishReviewCount = try container.decode(Int.self, forKey: .visibleDishReviewCount)
        isMe = try container.decode(Bool.self, forKey: .isMe)
        supportsPrivacySettings = container.contains(.reviewVisibility)
            && container.contains(.friendListVisibility)
            && container.contains(.profileVisibility)
            && container.contains(.profilePictureVisibility)
            && container.contains(.canViewProfile)
            && container.contains(.canViewFriends)
            && container.contains(.canViewProfilePicture)
        reviewVisibility = try container.decodeIfPresent(VisibilityStatus.self, forKey: .reviewVisibility) ?? .friendsOnly
        friendListVisibility = try container.decodeIfPresent(VisibilityStatus.self, forKey: .friendListVisibility) ?? .friendsOnly
        profileVisibility = try container.decodeIfPresent(VisibilityStatus.self, forKey: .profileVisibility) ?? .public
        profilePictureVisibility = try container.decodeIfPresent(VisibilityStatus.self, forKey: .profilePictureVisibility) ?? .public
        canViewProfile = try container.decodeIfPresent(Bool.self, forKey: .canViewProfile) ?? true
        canViewFriends = try container.decodeIfPresent(Bool.self, forKey: .canViewFriends) ?? true
        canViewReviews = try container.decodeIfPresent(Bool.self, forKey: .canViewReviews) ?? true
        canViewProfilePicture = try container.decodeIfPresent(Bool.self, forKey: .canViewProfilePicture) ?? true
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
