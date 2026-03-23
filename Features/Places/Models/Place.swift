import Foundation
import MapKit
import SwiftData

@Model
final class Place {
    var id: UUID
    var appleMapsPlaceId: String?
    var name: String
    var latitude: Double
    var longitude: Double
    var address: String
    var sourceType: PlaceSourceType
    var createdByUserId: UUID?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        appleMapsPlaceId: String? = nil,
        name: String,
        latitude: Double,
        longitude: Double,
        address: String,
        sourceType: PlaceSourceType,
        createdByUserId: UUID? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.appleMapsPlaceId = appleMapsPlaceId
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.sourceType = sourceType
        self.createdByUserId = createdByUserId
        self.createdAt = createdAt
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
