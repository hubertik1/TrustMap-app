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

    init(
        id: UUID = UUID(),
        name: String,
        latitude: Double,
        longitude: Double,
        address: String,
        city: String? = nil,
        countryCode: String? = nil
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.city = city
        self.countryCode = countryCode
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
            countryCode: countryCode
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
            countryCode: countryCode
        )
    }
}
