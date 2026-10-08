import Foundation
import MapKit

@MainActor
final class PlaceRepository {
    private struct CreatePlacePayload: Encodable {
        let name: String
        let address: String
        let city: String?
        let countryCode: String?
        let latitude: Double
        let longitude: Double
        let provider: String?
        let providerPlaceId: String?
    }

    private struct UpdateCustomPlaceDisplayNamePayload: Encodable {
        let displayName: String
    }

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func fetchPlaces(take: Int = 50) async throws -> [Place] {
        try await apiClient.send(
            APIRequest<[Place]>(
                method: .get,
                path: "places",
                queryItems: [URLQueryItem(name: "take", value: String(take))]
            )
        )
    }

    func recentPlaces(limit: Int = 12) async throws -> [Place] {
        try await fetchPlaces(take: limit)
    }

    func searchPlaces(query: String, take: Int = 20) async throws -> [Place] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return []
        }

        return try await apiClient.send(
            APIRequest<[Place]>(
                method: .get,
                path: "places/search",
                queryItems: [
                    URLQueryItem(name: "q", value: normalized),
                    URLQueryItem(name: "take", value: String(take))
                ]
            )
        )
    }

    func fetchPlaceDetails(id: UUID) async throws -> PlaceDetails {
        try await apiClient.send(
            APIRequest<PlaceDetails>(
                method: .get,
                path: "places/\(id.uuidString)"
            )
        )
    }

    func createOrGetPlace(from result: PlaceSearchResult) async throws -> Place {
        guard let coordinate = result.coordinate else {
            throw AppError.invalidPlaceSelection
        }

        let payload = CreatePlacePayload(
            name: result.name,
            address: result.subtitle,
            city: result.city,
            countryCode: result.countryCode,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            provider: result.mapItem == nil ? nil : "apple-maps",
            providerPlaceId: result.mapItem == nil ? nil : result.id
        )

        let place = try await apiClient.send(
            APIRequest<Place>(
                method: .post,
                path: "places",
                body: .json(AnyEncodable(payload)),
                acceptedStatusCodes: [201]
            )
        )

        guard result.mapItem == nil else {
            return place
        }

        return Place(
            id: place.id,
            name: place.name,
            displayName: place.customDisplayName ?? place.address,
            customDisplayName: place.customDisplayName,
            sourceType: .customPin,
            canEditCustomDisplayName: place.canEditCustomDisplayName,
            latitude: place.latitude,
            longitude: place.longitude,
            address: place.address,
            city: place.city,
            countryCode: place.countryCode,
            createdByUserId: place.createdByUserId,
            categoryNames: place.categoryNames
        )
    }

    func updateCustomDisplayName(placeID: UUID, displayName: String) async throws -> Place {
        let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDisplayName.isEmpty else {
            throw AppError.validationFailure(L10n.enterAPlaceName)
        }

        return try await apiClient.send(
            APIRequest<Place>(
                method: .patch,
                path: "places/\(placeID.uuidString)/custom-display-name",
                body: .json(AnyEncodable(UpdateCustomPlaceDisplayNamePayload(displayName: trimmedDisplayName))),
                acceptedStatusCodes: [200]
            )
        )
    }
}

@MainActor
final class CategoryRepository {
    private struct CreateCategoryPayload: Encodable {
        let name: String
        let iconName: String?
    }

    private struct UpdateCategoryPayload: Encodable {
        let name: String
        let iconName: String?
    }

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func fetchMyCategories() async throws -> [CustomCategory] {
        try await apiClient.send(
            APIRequest<[CustomCategory]>(
                method: .get,
                path: "categories/my"
            )
        )
    }

    func fetchFriendCategories() async throws -> [CustomCategory] {
        try await apiClient.send(
            APIRequest<[CustomCategory]>(
                method: .get,
                path: "categories/friends"
            )
        )
    }

    func fetchHiddenCategories() async throws -> [CustomCategory] {
        try await apiClient.send(
            APIRequest<[CustomCategory]>(
                method: .get,
                path: "categories/hidden"
            )
        )
    }

    func createCategory(name: String, iconName: String? = nil) async throws -> CustomCategory {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw AppError.validationFailure(L10n.enterACategoryName)
        }

        return try await apiClient.send(
            APIRequest<CustomCategory>(
                method: .post,
                path: "categories",
                body: .json(AnyEncodable(CreateCategoryPayload(name: trimmedName, iconName: iconName))),
                acceptedStatusCodes: [200, 201]
            )
        )
    }

    func adoptCategory(id: UUID) async throws -> CustomCategory {
        try await apiClient.send(
            APIRequest<CustomCategory>(
                method: .post,
                path: "categories/\(id.uuidString)/adopt",
                acceptedStatusCodes: [200]
            )
        )
    }

    func hideCategory(id: UUID) async throws -> CustomCategory {
        try await apiClient.send(
            APIRequest<CustomCategory>(
                method: .post,
                path: "categories/\(id.uuidString)/hide",
                acceptedStatusCodes: [200]
            )
        )
    }

    func unhideCategory(id: UUID) async throws -> CustomCategory {
        try await apiClient.send(
            APIRequest<CustomCategory>(
                method: .post,
                path: "categories/\(id.uuidString)/unhide",
                acceptedStatusCodes: [200]
            )
        )
    }

    func updateCategory(id: UUID, name: String, iconName: String? = nil) async throws -> CustomCategory {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw AppError.validationFailure(L10n.enterACategoryName)
        }

        return try await apiClient.send(
            APIRequest<CustomCategory>(
                method: .patch,
                path: "categories/\(id.uuidString)",
                body: .json(AnyEncodable(UpdateCategoryPayload(name: trimmedName, iconName: iconName))),
                acceptedStatusCodes: [200]
            )
        )
    }

    func deleteCategory(id: UUID) async throws {
        _ = try await apiClient.send(
            APIRequest<EmptyResponse>(
                method: .delete,
                path: "categories/\(id.uuidString)",
                acceptedStatusCodes: [204]
            )
        )
    }
}
