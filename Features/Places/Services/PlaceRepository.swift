import Foundation
import SwiftData

@MainActor
final class PlaceRepository {
    private let persistenceController: PersistenceController
    private let cloudKitSyncService: CloudKitSyncing

    init(
        persistenceController: PersistenceController,
        cloudKitSyncService: CloudKitSyncing
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

        let appleMapsPlaceID = searchResult.id

        if let existingPlace = try allPlaces().first(where: { $0.appleMapsPlaceId == appleMapsPlaceID }) {
            return existingPlace
        }

        let place = Place(
            appleMapsPlaceId: appleMapsPlaceID,
            name: searchResult.name,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            address: searchResult.subtitle,
            sourceType: .appleMaps,
            createdByUserId: createdByUserID
        )
        context.insert(place)
        try saveChanges()
        Task { await cloudKitSyncService.syncPlace(place) }
        return place
    }

    private func allPlaces() throws -> [Place] {
        let descriptor = FetchDescriptor<Place>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return try context.fetch(descriptor)
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
