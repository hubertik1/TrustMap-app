import Foundation

struct PlaceReview: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let placeId: UUID
    let categoryId: UUID?
    let categoryName: String?
    let visibility: VisibilityStatus
    let ratingOverall: Int
    let reviewText: String
    let descriptionText: String
    let createdAt: Date
    let updatedAt: Date
    let author: UserSummary
    let place: Place
    let photos: [PhotoAsset]

    enum CodingKeys: String, CodingKey {
        case author
        case categoryId
        case categoryName
        case createdAt = "createdAtUtc"
        case descriptionText = "body"
        case id
        case photos
        case place
        case placeId
        case ratingOverall = "rating"
        case reviewText = "title"
        case updatedAt = "updatedAtUtc"
        case visibility
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        placeId = try container.decode(UUID.self, forKey: .placeId)
        categoryId = try container.decodeIfPresent(UUID.self, forKey: .categoryId)
        categoryName = try container.decodeIfPresent(String.self, forKey: .categoryName)
        visibility = try container.decode(VisibilityStatus.self, forKey: .visibility)
        ratingOverall = try container.decode(Int.self, forKey: .ratingOverall)
        reviewText = try container.decodeIfPresent(String.self, forKey: .reviewText) ?? ""
        descriptionText = try container.decodeIfPresent(String.self, forKey: .descriptionText) ?? ""
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        author = try container.decode(UserSummary.self, forKey: .author)
        place = try container.decode(Place.self, forKey: .place)
        photos = try container.decode([PhotoAsset].self, forKey: .photos)
    }

    init(
        id: UUID = UUID(),
        placeId: UUID,
        categoryId: UUID? = nil,
        categoryName: String? = nil,
        visibility: VisibilityStatus = .friendsOnly,
        ratingOverall: Int,
        reviewText: String,
        descriptionText: String,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        author: UserSummary,
        place: Place,
        photos: [PhotoAsset] = []
    ) {
        self.id = id
        self.placeId = placeId
        self.categoryId = categoryId
        self.categoryName = categoryName
        self.visibility = visibility
        self.ratingOverall = ratingOverall
        self.reviewText = reviewText
        self.descriptionText = descriptionText
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.author = author
        self.place = place
        self.photos = photos
    }

    var authorUserId: UUID {
        author.id
    }
}
