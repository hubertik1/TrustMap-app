import Foundation

enum CategoryMembershipSourceValue: String, Codable, Hashable, Sendable {
    case defaultCategory = "Default"
    case ownCustom = "OwnCustom"
    case friendCustomAdded = "FriendCustomAdded"
}

struct CustomCategory: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let ownerUserId: UUID?
    let owner: UserSummary?
    let name: String
    let iconName: String?
    let isDefault: Bool
    let isOwnedByCurrentUser: Bool
    let currentUserSource: CategoryMembershipSourceValue?
    let isVisibleForCurrentUser: Bool
    let isAdoptedByCurrentUser: Bool
    let canEdit: Bool
    let canDelete: Bool
    let canHide: Bool
    let canAdopt: Bool
    let canUnhide: Bool
    let createdAt: Date
    let addedAt: Date?
    let hiddenAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case ownerUserId
        case owner
        case name
        case iconName
        case isDefault
        case isOwnedByCurrentUser
        case currentUserSource
        case isVisibleForCurrentUser
        case isAdoptedByCurrentUser
        case canEdit
        case canDelete
        case canHide
        case canAdopt
        case canUnhide
        case createdAt = "createdAtUtc"
        case addedAt = "addedAtUtc"
        case hiddenAt = "hiddenAtUtc"
    }

    init(
        id: UUID = UUID(),
        ownerUserId: UUID?,
        owner: UserSummary? = nil,
        name: String,
        iconName: String? = nil,
        isDefault: Bool = false,
        isOwnedByCurrentUser: Bool = false,
        currentUserSource: CategoryMembershipSourceValue? = nil,
        isVisibleForCurrentUser: Bool = true,
        isAdoptedByCurrentUser: Bool = false,
        canEdit: Bool = false,
        canDelete: Bool = false,
        canHide: Bool = false,
        canAdopt: Bool = false,
        canUnhide: Bool = false,
        createdAt: Date = .now,
        addedAt: Date? = nil,
        hiddenAt: Date? = nil
    ) {
        self.id = id
        self.ownerUserId = ownerUserId
        self.owner = owner
        self.name = name
        self.iconName = iconName
        self.isDefault = isDefault
        self.isOwnedByCurrentUser = isOwnedByCurrentUser
        self.currentUserSource = currentUserSource
        self.isVisibleForCurrentUser = isVisibleForCurrentUser
        self.isAdoptedByCurrentUser = isAdoptedByCurrentUser
        self.canEdit = canEdit
        self.canDelete = canDelete
        self.canHide = canHide
        self.canAdopt = canAdopt
        self.canUnhide = canUnhide
        self.createdAt = createdAt
        self.addedAt = addedAt
        self.hiddenAt = hiddenAt
    }

    var ownerDisplayName: String? {
        owner?.displayName
    }

    var isFriendCategory: Bool {
        !isDefault && !isOwnedByCurrentUser
    }
}
