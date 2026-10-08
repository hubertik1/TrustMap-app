import Foundation

enum TrustMapNotificationType: String, Codable, Sendable {
    case placeReviewAdded = "PlaceReviewAdded"
    case dishReviewAdded = "DishReviewAdded"
    case friendRequestSent = "FriendRequestSent"
}

struct TrustMapNotification: Identifiable, Decodable, Hashable, Sendable {
    let id: UUID
    let type: TrustMapNotificationType
    let createdAtUtc: Date
    let readAtUtc: Date?
    let actor: UserSummary
    let placeId: UUID?
    let placeName: String?
    let placeReviewId: UUID?
    let dishReviewId: UUID?
    let dishName: String?
    let friendRequestId: UUID?
    let friendRequestStatus: FriendInviteStatus?
    let rating: Int?

    var isUnread: Bool {
        readAtUtc == nil
    }

    var actorHandleBase: String {
        let base = actor.handleComponents.base.trimmingCharacters(in: .whitespacesAndNewlines)
        if !base.isEmpty {
            return base
        }

        return actor.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var title: String {
        switch type {
        case .placeReviewAdded:
            return L10n.valueAddedAPlaceReview(String(describing: actorMention))
        case .dishReviewAdded:
            return L10n.valueAddedADishReview(String(describing: actorMention))
        case .friendRequestSent:
            return L10n.valueSentYouAFriendRequest(String(describing: actorMention))
        }
    }

    var subtitle: String {
        switch type {
        case .placeReviewAdded:
            return [placeName, ratingText]
                .compactMap { $0?.nilIfEmpty }
                .joined(separator: " • ")

        case .dishReviewAdded:
            let dishAndPlace: String?
            if let dishName = dishName?.nilIfEmpty, let placeName = placeName?.nilIfEmpty {
                dishAndPlace = L10n.valueAtValue(String(describing: dishName), String(describing: placeName))
            } else {
                dishAndPlace = dishName?.nilIfEmpty ?? placeName?.nilIfEmpty
            }

            return [dishAndPlace, ratingText]
                .compactMap { $0?.nilIfEmpty }
                .joined(separator: " • ")

        case .friendRequestSent:
            return L10n.openFriendsToRespond
        }
    }

    var systemImage: String {
        switch type {
        case .placeReviewAdded:
            return "mappin.and.ellipse"
        case .dishReviewAdded:
            return "fork.knife"
        case .friendRequestSent:
            return "person.crop.circle.badge.plus"
        }
    }

    init(
        id: UUID,
        type: TrustMapNotificationType,
        createdAtUtc: Date,
        readAtUtc: Date?,
        actor: UserSummary,
        placeId: UUID?,
        placeName: String?,
        placeReviewId: UUID?,
        dishReviewId: UUID?,
        dishName: String?,
        friendRequestId: UUID?,
        friendRequestStatus: FriendInviteStatus?,
        rating: Int?
    ) {
        self.id = id
        self.type = type
        self.createdAtUtc = createdAtUtc
        self.readAtUtc = readAtUtc
        self.actor = actor
        self.placeId = placeId
        self.placeName = placeName
        self.placeReviewId = placeReviewId
        self.dishReviewId = dishReviewId
        self.dishName = dishName
        self.friendRequestId = friendRequestId
        self.friendRequestStatus = friendRequestStatus
        self.rating = rating
    }

    func markedRead(at date: Date = Date()) -> TrustMapNotification {
        TrustMapNotification(
            id: id,
            type: type,
            createdAtUtc: createdAtUtc,
            readAtUtc: readAtUtc ?? date,
            actor: actor,
            placeId: placeId,
            placeName: placeName,
            placeReviewId: placeReviewId,
            dishReviewId: dishReviewId,
            dishName: dishName,
            friendRequestId: friendRequestId,
            friendRequestStatus: friendRequestStatus,
            rating: rating
        )
    }

    private var actorMention: String {
        let base = actorHandleBase
        guard !base.isEmpty else {
            return L10n.someone
        }

        return base.hasPrefix("@") ? base : "@\(base)"
    }

    private var ratingText: String? {
        rating.map { "\($0)★" }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
