import Foundation
import MapKit

struct PlaceSearchResult: Identifiable {
    let id: String
    let mapItem: MKMapItem

    init(mapItem: MKMapItem) {
        let identifier = mapItem.placemark.coordinate.latitude.description
            + "-"
            + mapItem.placemark.coordinate.longitude.description
            + "-"
            + (mapItem.name ?? UUID().uuidString)
        self.id = identifier
        self.mapItem = mapItem
    }

    var name: String {
        mapItem.name ?? "Unknown Place"
    }

    var subtitle: String {
        mapItem.formattedAddress
    }

    var coordinate: CLLocationCoordinate2D {
        mapItem.placemark.coordinate
    }
}
