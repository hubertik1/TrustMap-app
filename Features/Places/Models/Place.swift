import Foundation
import MapKit

struct Place: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let name: String
    let address: String
    let city: String?
    let countryCode: String?
    let latitude: Double
    let longitude: Double
    let categoryNames: [String]

    enum CodingKeys: String, CodingKey {
        case address
        case categoryNames
        case city
        case countryCode
        case id
        case latitude
        case longitude
        case name
    }

    init(
        id: UUID = UUID(),
        name: String,
        latitude: Double,
        longitude: Double,
        address: String,
        city: String? = nil,
        countryCode: String? = nil,
        categoryNames: [String] = []
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.city = city
        self.countryCode = countryCode
        self.categoryNames = categoryNames
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        address = try container.decode(String.self, forKey: .address)
        city = try container.decodeIfPresent(String.self, forKey: .city)
        countryCode = try container.decodeIfPresent(String.self, forKey: .countryCode)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
        categoryNames = try container.decodeIfPresent([String].self, forKey: .categoryNames) ?? []
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
}

struct PlaceDetails: Codable, Hashable, Sendable {
    let id: UUID
    let name: String
    let address: String
    let city: String?
    let countryCode: String?
    let latitude: Double
    let longitude: Double
    let categoryNames: [String]
    let visiblePlaceReviewCount: Int
    let visibleDishReviewCount: Int
    let averagePlaceRating: Double?
    let viewerPlaceReviewId: UUID?
    let viewerDishReviewCount: Int
    let latestActivityAtUtc: Date?

    var place: Place {
        Place(
            id: id,
            name: name,
            latitude: latitude,
            longitude: longitude,
            address: address,
            city: city,
            countryCode: countryCode,
            categoryNames: categoryNames
        )
    }
}

struct MapPlace: Identifiable, Codable, Hashable, Sendable {
    let placeId: UUID
    let name: String
    let address: String
    let city: String?
    let countryCode: String?
    let latitude: Double
    let longitude: Double
    let categoryNames: [String]
    let visiblePlaceReviewCount: Int
    let visibleDishReviewCount: Int
    let averagePlaceRating: Double?
    let contributorCount: Int
    let latestActivityAtUtc: Date

    var id: UUID {
        placeId
    }

    var place: Place {
        Place(
            id: placeId,
            name: name,
            latitude: latitude,
            longitude: longitude,
            address: address,
            city: city,
            countryCode: countryCode,
            categoryNames: categoryNames
        )
    }
}
