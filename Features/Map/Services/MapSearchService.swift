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
