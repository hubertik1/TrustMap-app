import Foundation
import MapKit

@MainActor
final class MapSearchService {
    func search(query: String, region: MKCoordinateRegion?) async throws -> [PlaceSearchResult] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else {
            return []
        }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = normalizedQuery
        request.resultTypes = [.address, .pointOfInterest]
        if let region {
            request.region = region
        }

        let response = try await MKLocalSearch(request: request).start()
        return response.mapItems.map(PlaceSearchResult.init(mapItem:))
    }
}
