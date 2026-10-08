import CoreLocation
import Foundation
import MapKit

@MainActor
final class MapSearchService {
    func search(query: String, region: MKCoordinateRegion?) async throws -> [PlaceSearchResult] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedQuery.count >= 2 else {
            return []
        }

        let completer = SearchCompleter(query: normalizedQuery, region: region)
        return try await completer.results()
    }

    func resolve(_ result: PlaceSearchResult, region: MKCoordinateRegion?) async throws -> PlaceSearchResult {
        if result.mapItem != nil {
            return result
        }

        guard let completion = result.completion else {
            throw AppError.invalidPlaceSelection
        }

        let request = MKLocalSearch.Request(completion: completion)
        request.resultTypes = [.address, .pointOfInterest]
        if let region {
            request.region = region
            if #available(iOS 18.0, *) {
                request.regionPriority = .required
            }
        }

        let response = try await MKLocalSearch(request: request).start()
        guard let firstResult = response.mapItems.first else {
            throw AppError.invalidPlaceSelection
        }

        return PlaceSearchResult(mapItem: firstResult)
    }

    func resolveFeature(
        title: String?,
        coordinate: CLLocationCoordinate2D,
        region: MKCoordinateRegion?
    ) async throws -> PlaceSearchResult {
        let mapItem = try await nearestPointOfInterest(
            to: coordinate,
            matching: title,
            region: region
        )

        if let mapItem {
            return PlaceSearchResult(mapItem: mapItem)
        }

        return try await reverseGeocodedPlace(
            at: coordinate,
            fallbackName: title ?? L10n.selectedPlace
        )
    }

    func resolveMapTap(at coordinate: CLLocationCoordinate2D) async throws -> PlaceSearchResult {
        if let pointOfInterest = try await nearestPointOfInterest(to: coordinate, matching: nil, region: nil) {
            return PlaceSearchResult(mapItem: pointOfInterest)
        }

        return try await reverseGeocodedPlace(at: coordinate)
    }

    func resolveDroppedPin(at coordinate: CLLocationCoordinate2D) async throws -> PlaceSearchResult {
        try await reverseGeocodedPlace(at: coordinate, fallbackName: L10n.pinnedLocation)
    }

    private func nearestPointOfInterest(
        to coordinate: CLLocationCoordinate2D,
        matching title: String?,
        region: MKCoordinateRegion?
    ) async throws -> MKMapItem? {
        let referenceLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let normalizedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let normalizedTitle, !normalizedTitle.isEmpty {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = normalizedTitle
            request.resultTypes = [.pointOfInterest, .address]
            request.region = MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003))
            if #available(iOS 18.0, *) {
                request.regionPriority = .required
            }

            let response = try await MKLocalSearch(request: request).start()
            let matchingItems = response.mapItems.filter { item in
                guard let itemName = item.name else {
                    return false
                }

                return itemName.localizedCaseInsensitiveContains(normalizedTitle)
                    || normalizedTitle.localizedCaseInsensitiveContains(itemName)
            }

            if let nearestMatchingItem = nearestItem(from: matchingItems, referenceLocation: referenceLocation) {
                return nearestMatchingItem
            }
        }

        let request = MKLocalPointsOfInterestRequest(center: coordinate, radius: 180)
        let response = try await MKLocalSearch(request: request).start()
        return nearestItem(from: response.mapItems, referenceLocation: referenceLocation)
    }

    private func nearestItem(from items: [MKMapItem], referenceLocation: CLLocation) -> MKMapItem? {
        items.min { lhs, rhs in
            let lhsDistance = referenceLocation.distance(from: CLLocation(latitude: lhs.placemark.coordinate.latitude, longitude: lhs.placemark.coordinate.longitude))
            let rhsDistance = referenceLocation.distance(from: CLLocation(latitude: rhs.placemark.coordinate.latitude, longitude: rhs.placemark.coordinate.longitude))
            return lhsDistance < rhsDistance
        }
    }

    private func reverseGeocodedPlace(
        at coordinate: CLLocationCoordinate2D,
        fallbackName: String = L10n.droppedPin
    ) async throws -> PlaceSearchResult {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
        let placemark = placemarks.first

        let streetLine = [
            placemark?.thoroughfare,
            placemark?.subThoroughfare
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
        .joined(separator: " ")

        let localityLine = [
            placemark?.postalCode,
            placemark?.locality
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
        .joined(separator: " ")

        let address = [streetLine, localityLine]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")

        let displayName = placemark?.name
            ?? (streetLine.isEmpty ? nil : streetLine)
            ?? (localityLine.isEmpty ? nil : localityLine)
            ?? fallbackName

        return PlaceSearchResult(
            name: displayName,
            subtitle: address.isEmpty ? L10n.selectedFromMap : address,
            coordinate: coordinate
        )
    }
}

private final class SearchCompleter: NSObject, MKLocalSearchCompleterDelegate {
    private let completer = MKLocalSearchCompleter()
    private let query: String
    private var continuation: CheckedContinuation<[PlaceSearchResult], Error>?

    init(query: String, region: MKCoordinateRegion?) {
        self.query = query
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest, .query]
        if let region {
            completer.region = region
            if #available(iOS 18.0, *) {
                completer.regionPriority = .required
            }
        }
    }

    func results() async throws -> [PlaceSearchResult] {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            completer.queryFragment = query
        }
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        continuation?.resume(returning: completer.results.map(PlaceSearchResult.init(completion:)))
        continuation = nil
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: any Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

@MainActor
final class MapRepository {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func fetchMapPlaces(
        north: Double? = nil,
        south: Double? = nil,
        east: Double? = nil,
        west: Double? = nil,
        categoryID: UUID? = nil,
        take: Int = 250
    ) async throws -> [MapPlace] {
        var queryItems = [URLQueryItem(name: "take", value: String(take))]

        if let north, let south, let east, let west {
            queryItems.append(contentsOf: [
                URLQueryItem(name: "north", value: String(north)),
                URLQueryItem(name: "south", value: String(south)),
                URLQueryItem(name: "east", value: String(east)),
                URLQueryItem(name: "west", value: String(west))
            ])
        }

        if let categoryID {
            queryItems.append(URLQueryItem(name: "categoryId", value: categoryID.uuidString))
        }

        return try await apiClient.send(
            APIRequest<[MapPlace]>(
                method: .get,
                path: "map/places",
                queryItems: queryItems
            )
        )
    }

    func fetchMapPins(
        north: Double,
        south: Double,
        east: Double,
        west: Double
    ) async throws -> [MapPin] {
        try await apiClient.send(
            APIRequest<[MapPin]>(
                method: .get,
                path: "map/pins",
                queryItems: [
                    URLQueryItem(name: "north", value: String(north)),
                    URLQueryItem(name: "south", value: String(south)),
                    URLQueryItem(name: "east", value: String(east)),
                    URLQueryItem(name: "west", value: String(west))
                ]
            )
        )
    }

    func fetchMapPin(placeId: UUID) async throws -> MapPin? {
        try await apiClient.send(
            APIRequest<MapPin?>(
                method: .get,
                path: "map/pins/\(placeId.uuidString)"
            )
        )
    }
}
