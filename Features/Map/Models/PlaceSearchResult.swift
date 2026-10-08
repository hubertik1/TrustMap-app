import Foundation
import MapKit

struct PlaceSearchResult: Identifiable, @unchecked Sendable {
    let id: String
    let mapItem: MKMapItem?
    let completion: MKLocalSearchCompletion?
    private let fallbackName: String
    private let fallbackSubtitle: String
    private let fallbackCoordinate: CLLocationCoordinate2D?

    init(mapItem: MKMapItem) {
        let identifier = mapItem.placemark.coordinate.latitude.description
            + "-"
            + mapItem.placemark.coordinate.longitude.description
            + "-"
            + (mapItem.name ?? UUID().uuidString)
        self.id = identifier
        self.mapItem = mapItem
        self.completion = nil
        self.fallbackName = mapItem.name ?? L10n.unknownPlace
        self.fallbackSubtitle = mapItem.formattedAddress
        self.fallbackCoordinate = mapItem.placemark.coordinate
    }

    init(completion: MKLocalSearchCompletion) {
        self.id = completion.title + "-" + completion.subtitle
        self.mapItem = nil
        self.completion = completion
        self.fallbackName = completion.title
        self.fallbackSubtitle = completion.subtitle
        self.fallbackCoordinate = nil
    }

    init(name: String, subtitle: String, coordinate: CLLocationCoordinate2D) {
        self.id = coordinate.latitude.description + "-" + coordinate.longitude.description + "-" + name
        self.mapItem = nil
        self.completion = nil
        self.fallbackName = name
        self.fallbackSubtitle = subtitle
        self.fallbackCoordinate = coordinate
    }

    var name: String {
        mapItem?.name ?? fallbackName
    }

    var subtitle: String {
        let resolvedSubtitle = mapItem?.formattedAddress ?? ""
        return resolvedSubtitle.isEmpty ? fallbackSubtitle : resolvedSubtitle
    }

    var coordinate: CLLocationCoordinate2D? {
        mapItem?.placemark.coordinate ?? fallbackCoordinate
    }
}
