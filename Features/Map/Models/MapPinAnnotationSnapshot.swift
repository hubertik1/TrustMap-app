import Foundation

struct MapPinAnnotationSnapshot {
    let annotations: [MapPlaceAnnotation]
    let hasVisibleAnnotationsInCurrentViewport: Bool
}

enum MapPinAnnotationBuilder {
    static func makeSnapshot(
        from pins: some Sequence<MapPin>,
        filterState: MapFilterState,
        viewportBounds: MapBounds?
    ) -> MapPinAnnotationSnapshot {
        let filteredPins = pins.filter { pin in
            if let categoryID = filterState.selectedCategory.categoryID,
               !pin.categoryIds.contains(categoryID) {
                return false
            }

            let matchesOwnership: Bool
            switch filterState.selectedOwnershipFilter {
            case .all:
                matchesOwnership = true
            case .mine:
                matchesOwnership = pin.isReviewedByCurrentUser
            }

            guard matchesOwnership else {
                return false
            }

            guard let average = pin.averageRating else {
                return filterState.minimumRating <= 1
            }

            return filterState.ratingRange.contains(Int(round(average)))
        }

        let annotations = filteredPins.sorted {
            ($0.latestActivityAtUtc ?? .distantPast) > ($1.latestActivityAtUtc ?? .distantPast)
        }.map {
            MapPlaceAnnotation(
                id: $0.placeId,
                place: annotationPlace(from: $0),
                averageRating: $0.averageRating ?? 0,
                reviewCount: $0.reviewCount,
                contributorCount: $0.contributorCount,
                recentContributors: []
            )
        }

        return MapPinAnnotationSnapshot(
            annotations: annotations,
            hasVisibleAnnotationsInCurrentViewport: viewportBounds.map { bounds in
                annotations.contains { bounds.contains($0.coordinate) }
            } ?? false
        )
    }

    private static func annotationPlace(from pin: MapPin) -> Place {
        let trimmedDisplayName = pin.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedDisplayName: String
        if let trimmedDisplayName, !trimmedDisplayName.isEmpty {
            resolvedDisplayName = trimmedDisplayName
        } else {
            resolvedDisplayName = "Reviewed place"
        }

        return Place(
            id: pin.placeId,
            name: resolvedDisplayName,
            displayName: resolvedDisplayName,
            sourceType: .customPin,
            latitude: pin.latitude,
            longitude: pin.longitude,
            address: ""
        )
    }
}
