import Foundation
import MapKit
import SwiftData

@MainActor
final class PlaceRepository {
    private let persistenceController: PersistenceController
    private let cloudKitSyncService: CloudKitSyncService

    init(
        persistenceController: PersistenceController,
        cloudKitSyncService: CloudKitSyncService
    ) {
        self.persistenceController = persistenceController
        self.cloudKitSyncService = cloudKitSyncService
    }

    private var context: ModelContext {
        persistenceController.mainContext
    }

    func place(withID placeID: UUID) throws -> Place? {
        try allPlaces().first(where: { $0.id == placeID })
    }

    func places(withIDs ids: Set<UUID>) throws -> [Place] {
        try allPlaces().filter { ids.contains($0.id) }
    }

    func recentPlaces(limit: Int = 12) throws -> [Place] {
        Array(try allPlaces().sorted { $0.createdAt > $1.createdAt }.prefix(limit))
    }

    func localSearch(query: String) throws -> [Place] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else {
            return try recentPlaces()
        }

        return try allPlaces().filter {
            $0.name.localizedCaseInsensitiveContains(normalizedQuery)
                || $0.address.localizedCaseInsensitiveContains(normalizedQuery)
        }
    }

    func upsertPlace(from searchResult: PlaceSearchResult, createdByUserID: UUID?) throws -> Place {
        guard let coordinate = searchResult.coordinate else {
            throw AppError.invalidPlaceSelection
        }

        return try upsertPlace(
            appleMapsPlaceID: searchResult.mapItem == nil ? nil : searchResult.id,
            name: searchResult.name,
            coordinate: coordinate,
            address: searchResult.subtitle,
            sourceType: searchResult.mapItem == nil ? .manual : .appleMaps,
            createdByUserID: createdByUserID
        )
    }

    func upsertPlace(
        appleMapsPlaceID: String? = nil,
        name: String,
        coordinate: CLLocationCoordinate2D,
        address: String,
        sourceType: PlaceSourceType,
        createdByUserID: UUID?
    ) throws -> Place {
        if let appleMapsPlaceID,
           let existingPlace = try allPlaces().first(where: { $0.appleMapsPlaceId == appleMapsPlaceID }) {
            return try refreshExistingPlace(
                existingPlace,
                appleMapsPlaceID: appleMapsPlaceID,
                name: name,
                coordinate: coordinate,
                address: address,
                sourceType: sourceType,
                currentUserID: createdByUserID
            )
        }

        if let existingManualPlace = try allPlaces().first(where: {
            $0.appleMapsPlaceId == nil
                && $0.name == name
                && abs($0.latitude - coordinate.latitude) < 0.0003
                && abs($0.longitude - coordinate.longitude) < 0.0003
        }) {
            return try refreshExistingPlace(
                existingManualPlace,
                appleMapsPlaceID: appleMapsPlaceID,
                name: name,
                coordinate: coordinate,
                address: address,
                sourceType: sourceType,
                currentUserID: createdByUserID
            )
        }

        let place = Place(
            appleMapsPlaceId: appleMapsPlaceID,
            name: name,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            address: address,
            sourceType: sourceType,
            createdByUserId: createdByUserID
        )
        context.insert(place)
        try saveChanges()
        if let createdByUserID {
            Task { await cloudKitSyncService.syncPlace(place, ownerUserID: createdByUserID) }
        } else {
            Task { await cloudKitSyncService.syncPlace(place) }
        }
        return place
    }

    private func allPlaces() throws -> [Place] {
        let descriptor = FetchDescriptor<Place>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        var seenPlaceIDs = Set<UUID>()
        return try context.fetch(descriptor).filter { seenPlaceIDs.insert($0.id).inserted }
    }

    private func refreshExistingPlace(
        _ place: Place,
        appleMapsPlaceID: String?,
        name: String,
        coordinate: CLLocationCoordinate2D,
        address: String,
        sourceType: PlaceSourceType,
        currentUserID: UUID?
    ) throws -> Place {
        var didChange = false

        if place.appleMapsPlaceId == nil, let appleMapsPlaceID {
            place.appleMapsPlaceId = appleMapsPlaceID
            didChange = true
        }

        if place.name != name {
            place.name = name
            didChange = true
        }

        if place.latitude != coordinate.latitude {
            place.latitude = coordinate.latitude
            didChange = true
        }

        if place.longitude != coordinate.longitude {
            place.longitude = coordinate.longitude
            didChange = true
        }

        if place.address != address {
            place.address = address
            didChange = true
        }

        if place.sourceType != sourceType {
            place.sourceType = sourceType
            didChange = true
        }

        if place.createdByUserId == nil, let currentUserID {
            place.createdByUserId = currentUserID
            didChange = true
        }

        if didChange {
            try saveChanges()
        }

        if let currentUserID {
            Task { await cloudKitSyncService.syncPlace(place, ownerUserID: currentUserID) }
        }

        return place
    }

    private func saveChanges() throws {
        do {
            if context.hasChanges {
                try context.save()
            }
        } catch {
            throw AppError.persistenceFailure("Unable to save the selected place.")
        }
    }
}
