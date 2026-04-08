import Foundation

struct DishReview: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let placeId: UUID
    let placeReviewId: UUID?
    let categoryId: UUID?
    let categoryName: String?
    let visibility: VisibilityStatus
    let dishName: String
    let dishRating: Int
    let dishReviewText: String
    let priceAmount: Decimal?
    let currencyCode: String?
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
        case currencyCode
        case dishName
        case dishRating = "rating"
        case dishReviewText = "body"
        case id
        case photos
        case place
        case placeId
        case placeReviewId
        case priceAmount
        case updatedAt = "updatedAtUtc"
        case visibility
    }

    init(
        id: UUID = UUID(),
        placeId: UUID,
        placeReviewId: UUID? = nil,
        categoryId: UUID? = nil,
        categoryName: String? = nil,
        visibility: VisibilityStatus = .friendsOnly,
        dishName: String,
        dishRating: Int,
        dishReviewText: String,
        priceAmount: Decimal? = nil,
        currencyCode: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        author: UserSummary,
        place: Place,
        photos: [PhotoAsset] = []
    ) {
        self.id = id
        self.placeId = placeId
        self.placeReviewId = placeReviewId
        self.categoryId = categoryId
        self.categoryName = categoryName
        self.visibility = visibility
        self.dishName = dishName
        self.dishRating = dishRating
        self.dishReviewText = dishReviewText
        self.priceAmount = priceAmount
        self.currencyCode = currencyCode
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.author = author
        self.place = place
        self.photos = photos
    }

    var authorUserId: UUID {
        author.id
    }

    var price: Double? {
        guard let priceAmount else {
            return nil
        }

        return NSDecimalNumber(decimal: priceAmount).doubleValue
    }
}

extension DishReview {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        placeId = try container.decode(UUID.self, forKey: .placeId)
        placeReviewId = try container.decodeIfPresent(UUID.self, forKey: .placeReviewId)
        categoryId = try container.decodeIfPresent(UUID.self, forKey: .categoryId)
        categoryName = try container.decodeIfPresent(String.self, forKey: .categoryName)
        visibility = try container.decode(VisibilityStatus.self, forKey: .visibility)
        dishName = try container.decode(String.self, forKey: .dishName)
        dishRating = try container.decode(Int.self, forKey: .dishRating)
        dishReviewText = try container.decodeIfPresent(String.self, forKey: .dishReviewText) ?? ""
        priceAmount = try container.decodeIfPresent(Decimal.self, forKey: .priceAmount)
        currencyCode = try container.decodeIfPresent(String.self, forKey: .currencyCode)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        author = try container.decode(UserSummary.self, forKey: .author)
        place = try container.decode(Place.self, forKey: .place)
        photos = try container.decode([PhotoAsset].self, forKey: .photos)
    }
}
