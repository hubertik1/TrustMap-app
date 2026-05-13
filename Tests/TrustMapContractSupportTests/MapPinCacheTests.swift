import XCTest
@testable import TrustMapContractSupport

final class MapPinCacheTests: XCTestCase {
    func testCachedPinsRemainInAnnotationsOutsideCurrentViewport() {
        let cachedPin = makePin(latitude: 50, longitude: 19)
        let offscreenViewport = MapBounds(north: 53, south: 52, east: 22, west: 21)

        let snapshot = MapPinAnnotationBuilder.makeSnapshot(
            from: [cachedPin],
            filterState: .defaultState,
            viewportBounds: offscreenViewport
        )

        XCTAssertEqual(snapshot.annotations.map(\.id), [cachedPin.placeId])
        XCTAssertFalse(snapshot.hasVisibleAnnotationsInCurrentViewport)
    }

    func testReturningToLoadedBoundsDoesNotNeedFetch() {
        let loadedBounds = MapBounds(north: 51, south: 49, east: 20, west: 18)
        let returningViewport = MapBounds(north: 50.5, south: 49.5, east: 19.5, west: 18.5)

        XCTAssertFalse(MapBoundsCoverage.shouldFetchPins(for: returningViewport, loadedBounds: [loadedBounds]))
    }

    func testDistantLoadedBoundsDoNotCoverTheGapBetweenThem() {
        let firstBounds = MapBounds(north: 51, south: 49, east: 20, west: 18)
        let secondBounds = MapBounds(north: 51, south: 49, east: 40, west: 38)
        let loadedBounds = MapBoundsCoverage.appending(secondBounds, to: [firstBounds])
        let middleViewport = MapBounds(north: 50.5, south: 49.5, east: 30, west: 29)

        XCTAssertEqual(loadedBounds.count, 2)
        XCTAssertTrue(MapBoundsCoverage.shouldFetchPins(for: middleViewport, loadedBounds: loadedBounds))
    }

    func testNoPinsOverlayCanShowWhenOnlyOffscreenCachedAnnotationsExist() {
        let cachedPin = makePin(latitude: 50, longitude: 19)
        let offscreenViewport = MapBounds(north: 53, south: 52, east: 22, west: 21)
        let snapshot = MapPinAnnotationBuilder.makeSnapshot(
            from: [cachedPin],
            filterState: .defaultState,
            viewportBounds: offscreenViewport
        )

        XCTAssertFalse(snapshot.annotations.isEmpty)
        XCTAssertFalse(snapshot.hasVisibleAnnotationsInCurrentViewport)
        XCTAssertTrue(MapStatusOverlayVisibility.shouldShowStatusOverlay(
            isPromptPresented: false,
            isDroppedPinPresented: false,
            hasSearchResults: false,
            searchText: "",
            errorMessage: nil,
            hasLoadedMapPlaces: true,
            isLoading: false,
            hasVisibleAnnotationsInCurrentViewport: snapshot.hasVisibleAnnotationsInCurrentViewport
        ))
    }

    private func makePin(
        id: UUID = UUID(),
        latitude: Double,
        longitude: Double,
        categoryIds: [UUID] = [],
        isReviewedByCurrentUser: Bool = false
    ) -> MapPin {
        MapPin(
            placeId: id,
            displayName: "Cached Place",
            latitude: latitude,
            longitude: longitude,
            averageRating: 4,
            reviewCount: 1,
            contributorCount: 1,
            categoryIds: categoryIds,
            isReviewedByCurrentUser: isReviewedByCurrentUser,
            latestActivityAtUtc: Date(timeIntervalSinceReferenceDate: 0)
        )
    }
}
