import Foundation
import MapKit

struct Place: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let name: String
    let displayName: String
    let customDisplayName: String?
    let sourceType: PlaceSourceType
    let address: String
    let city: String?
    let countryCode: String?
    let latitude: Double
    let longitude: Double
    let createdByUserId: UUID?
    let categoryNames: [String]

    enum CodingKeys: String, CodingKey {
        case address
        case categoryNames
        case city
        case countryCode
        case createdByUserId
        case customDisplayName
        case displayName
        case id
        case latitude
        case longitude
        case name
        case sourceType
    }

    init(
        id: UUID = UUID(),
        name: String,
        displayName: String? = nil,
        customDisplayName: String? = nil,
        sourceType: PlaceSourceType = .providerVenue,
        latitude: Double,
        longitude: Double,
        address: String,
        city: String? = nil,
        countryCode: String? = nil,
        createdByUserId: UUID? = nil,
        categoryNames: [String] = []
    ) {
        self.id = id
        self.name = name
        self.customDisplayName = customDisplayName
        self.sourceType = sourceType
        self.displayName = displayName ?? Self.resolvedDisplayName(
            name: name,
            address: address,
            sourceType: sourceType,
            customDisplayName: customDisplayName
        )
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.city = city
        self.countryCode = countryCode
        self.createdByUserId = createdByUserId
        self.categoryNames = categoryNames
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        customDisplayName = try container.decodeIfPresent(String.self, forKey: .customDisplayName)
        sourceType = try container.decodeIfPresent(PlaceSourceType.self, forKey: .sourceType) ?? .providerVenue
        address = try container.decode(String.self, forKey: .address)
        city = try container.decodeIfPresent(String.self, forKey: .city)
        countryCode = try container.decodeIfPresent(String.self, forKey: .countryCode)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
        createdByUserId = try container.decodeIfPresent(UUID.self, forKey: .createdByUserId)
        categoryNames = try container.decodeIfPresent([String].self, forKey: .categoryNames) ?? []
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
            ?? Self.resolvedDisplayName(
                name: name,
                address: address,
                sourceType: sourceType,
                customDisplayName: customDisplayName
            )
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var subtitle: String {
        [address, city, countryCode]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    var supportsDishReviews: Bool {
        categoryNames.contains { categoryName in
            categoryName.compare("Restaurant", options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
    }

    var isCustomPin: Bool {
        sourceType == .customPin
    }

    var secondaryDisplayText: String? {
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAddress.isEmpty else {
            return nil
        }

        guard trimmedAddress.compare(displayName, options: [.caseInsensitive, .diacriticInsensitive]) != .orderedSame else {
            return nil
        }

        return trimmedAddress
    }

    func canRenameCustomDisplayName(as userID: UUID?) -> Bool {
        isCustomPin && createdByUserId == userID
    }

    private static func resolvedDisplayName(
        name: String,
        address: String,
        sourceType: PlaceSourceType,
        customDisplayName: String?
    ) -> String {
        if let customDisplayName,
           !customDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return customDisplayName
        }

        return sourceType == .customPin ? address : name
    }
}

struct PlaceDetails: Codable, Hashable, Sendable {
    let id: UUID
    let name: String
    let displayName: String
    let customDisplayName: String?
    let sourceType: PlaceSourceType
    let address: String
    let city: String?
    let countryCode: String?
    let latitude: Double
    let longitude: Double
    let createdByUserId: UUID?
    let categoryNames: [String]
    let visiblePlaceReviewCount: Int
    let visibleDishReviewCount: Int
    let averagePlaceRating: Double?
    let viewerPlaceReviewId: UUID?
    let viewerDishReviewCount: Int
    let latestActivityAtUtc: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case displayName
        case customDisplayName
        case sourceType
        case address
        case city
        case countryCode
        case latitude
        case longitude
        case createdByUserId
        case categoryNames
        case visiblePlaceReviewCount
        case visibleDishReviewCount
        case averagePlaceRating
        case viewerPlaceReviewId
        case viewerDishReviewCount
        case latestActivityAtUtc
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        customDisplayName = try container.decodeIfPresent(String.self, forKey: .customDisplayName)
        sourceType = try container.decodeIfPresent(PlaceSourceType.self, forKey: .sourceType) ?? .providerVenue
        address = try container.decode(String.self, forKey: .address)
        city = try container.decodeIfPresent(String.self, forKey: .city)
        countryCode = try container.decodeIfPresent(String.self, forKey: .countryCode)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
        createdByUserId = try container.decodeIfPresent(UUID.self, forKey: .createdByUserId)
        categoryNames = try container.decodeIfPresent([String].self, forKey: .categoryNames) ?? []
        visiblePlaceReviewCount = try container.decode(Int.self, forKey: .visiblePlaceReviewCount)
        visibleDishReviewCount = try container.decode(Int.self, forKey: .visibleDishReviewCount)
        averagePlaceRating = try container.decodeIfPresent(Double.self, forKey: .averagePlaceRating)
        viewerPlaceReviewId = try container.decodeIfPresent(UUID.self, forKey: .viewerPlaceReviewId)
        viewerDishReviewCount = try container.decode(Int.self, forKey: .viewerDishReviewCount)
        latestActivityAtUtc = try container.decodeIfPresent(Date.self, forKey: .latestActivityAtUtc)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
            ?? Place(
                id: id,
                name: name,
                customDisplayName: customDisplayName,
                sourceType: sourceType,
                latitude: latitude,
                longitude: longitude,
                address: address,
                city: city,
                countryCode: countryCode,
                createdByUserId: createdByUserId
            ).displayName
    }

    var place: Place {
        Place(
            id: id,
            name: name,
            displayName: displayName,
            customDisplayName: customDisplayName,
            sourceType: sourceType,
            latitude: latitude,
            longitude: longitude,
            address: address,
            city: city,
            countryCode: countryCode,
            createdByUserId: createdByUserId,
            categoryNames: categoryNames
        )
    }
}

struct MapPlace: Identifiable, Codable, Hashable, Sendable {
    let placeId: UUID
    let name: String
    let displayName: String
    let customDisplayName: String?
    let sourceType: PlaceSourceType
    let address: String
    let city: String?
    let countryCode: String?
    let latitude: Double
    let longitude: Double
    let createdByUserId: UUID?
    let categoryNames: [String]
    let visiblePlaceReviewCount: Int
    let visibleDishReviewCount: Int
    let averagePlaceRating: Double?
    let contributorCount: Int
    let latestActivityAtUtc: Date

    enum CodingKeys: String, CodingKey {
        case placeId
        case name
        case displayName
        case customDisplayName
        case sourceType
        case address
        case city
        case countryCode
        case latitude
        case longitude
        case createdByUserId
        case categoryNames
        case visiblePlaceReviewCount
        case visibleDishReviewCount
        case averagePlaceRating
        case contributorCount
        case latestActivityAtUtc
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        placeId = try container.decode(UUID.self, forKey: .placeId)
        name = try container.decode(String.self, forKey: .name)
        customDisplayName = try container.decodeIfPresent(String.self, forKey: .customDisplayName)
        sourceType = try container.decodeIfPresent(PlaceSourceType.self, forKey: .sourceType) ?? .providerVenue
        address = try container.decode(String.self, forKey: .address)
        city = try container.decodeIfPresent(String.self, forKey: .city)
        countryCode = try container.decodeIfPresent(String.self, forKey: .countryCode)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
        createdByUserId = try container.decodeIfPresent(UUID.self, forKey: .createdByUserId)
        categoryNames = try container.decodeIfPresent([String].self, forKey: .categoryNames) ?? []
        visiblePlaceReviewCount = try container.decode(Int.self, forKey: .visiblePlaceReviewCount)
        visibleDishReviewCount = try container.decode(Int.self, forKey: .visibleDishReviewCount)
        averagePlaceRating = try container.decodeIfPresent(Double.self, forKey: .averagePlaceRating)
        contributorCount = try container.decode(Int.self, forKey: .contributorCount)
        latestActivityAtUtc = try container.decode(Date.self, forKey: .latestActivityAtUtc)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
            ?? Place(
                id: placeId,
                name: name,
                customDisplayName: customDisplayName,
                sourceType: sourceType,
                latitude: latitude,
                longitude: longitude,
                address: address,
                city: city,
                countryCode: countryCode,
                createdByUserId: createdByUserId
            ).displayName
    }

    var id: UUID {
        placeId
    }

    var place: Place {
        Place(
            id: placeId,
            name: name,
            displayName: displayName,
            customDisplayName: customDisplayName,
            sourceType: sourceType,
            latitude: latitude,
            longitude: longitude,
            address: address,
            city: city,
            countryCode: countryCode,
            createdByUserId: createdByUserId,
            categoryNames: categoryNames
        )
    }
}
