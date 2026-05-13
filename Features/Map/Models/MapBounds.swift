import CoreLocation
import Foundation

struct MapBounds: Equatable, Sendable {
    let north: Double
    let south: Double
    let east: Double
    let west: Double

    func contains(_ other: MapBounds) -> Bool {
        other.north <= north
            && other.south >= south
            && other.east <= east
            && other.west >= west
    }

    func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        coordinate.latitude <= north
            && coordinate.latitude >= south
            && coordinate.longitude <= east
            && coordinate.longitude >= west
    }

    func intersects(_ other: MapBounds) -> Bool {
        !(other.west > east
            || other.east < west
            || other.south > north
            || other.north < south)
    }

    func union(_ other: MapBounds) -> MapBounds {
        MapBounds(
            north: max(north, other.north),
            south: min(south, other.south),
            east: max(east, other.east),
            west: min(west, other.west)
        )
    }
}

enum MapBoundsCoverage {
    static func shouldFetchPins(for viewportBounds: MapBounds, loadedBounds: [MapBounds]) -> Bool {
        !loadedBounds.contains { $0.contains(viewportBounds) }
    }

    static func appending(_ newBounds: MapBounds, to loadedBounds: [MapBounds]) -> [MapBounds] {
        var mergedBounds = newBounds
        var disjointBounds: [MapBounds] = []

        for existingBounds in loadedBounds {
            if existingBounds.intersects(mergedBounds) {
                mergedBounds = mergedBounds.union(existingBounds)
            } else {
                disjointBounds.append(existingBounds)
            }
        }

        disjointBounds.append(mergedBounds)
        return disjointBounds
    }
}
