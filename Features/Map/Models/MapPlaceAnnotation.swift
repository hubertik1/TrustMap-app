import Foundation
import MapKit

struct MapPlaceAnnotation: Identifiable {
    let id: UUID
    let place: Place
    let averageRating: Double
    let reviewCount: Int

    var coordinate: CLLocationCoordinate2D {
        place.coordinate
    }
}
