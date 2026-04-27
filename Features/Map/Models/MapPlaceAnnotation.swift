import Foundation
import MapKit

struct MapPlaceAnnotation: Identifiable {
    let id: UUID
    let place: Place
    let averageRating: Double
    let reviewCount: Int
    let contributorCount: Int
    let recentContributors: [UserSummary]

    var coordinate: CLLocationCoordinate2D {
        place.coordinate
    }
}
