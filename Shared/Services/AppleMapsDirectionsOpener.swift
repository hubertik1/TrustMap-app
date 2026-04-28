import CoreLocation
import MapKit

enum AppleMapsDirectionsOpener {
    static func canOpenDirections(to place: Place) -> Bool {
        isValidCoordinate(place.coordinate)
    }

    static func openDirections(to place: Place) {
        let coordinate = place.coordinate
        guard isValidCoordinate(coordinate) else {
            return
        }

        let destination = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        destination.name = place.displayName
        MKMapItem.openMaps(
            with: [
                MKMapItem.forCurrentLocation(),
                destination
            ],
            launchOptions: [
                MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
            ]
        )
    }

    private static func isValidCoordinate(_ coordinate: CLLocationCoordinate2D) -> Bool {
        coordinate.latitude.isFinite
            && coordinate.longitude.isFinite
            && CLLocationCoordinate2DIsValid(coordinate)
    }
}
