import Foundation

@MainActor
final class SafetyRepository {
    private struct ReportPayload: Encodable {
        let reviewType: String
        let reviewId: UUID
    }

    private let apiClient: APIClient
    private let refreshCenter: AppRefreshCenter
    private var knownBlockIDs: Set<UUID>?
    var onBlocksChanged: (() async -> Void)?

    init(apiClient: APIClient, refreshCenter: AppRefreshCenter) {
        self.apiClient = apiClient
        self.refreshCenter = refreshCenter
    }

    func fetchBlockedUsers() async throws -> [BlockedUser] {
        try await apiClient.send(APIRequest<[BlockedUser]>(method: .get, path: "me/blocks"))
    }

    func block(userID: UUID) async throws {
        _ = try await apiClient.send(APIRequest<EmptyResponse>(
            method: .put, path: "me/blocks/\(userID.uuidString)", acceptedStatusCodes: [204]
        ))
        knownBlockIDs?.insert(userID)
        RemoteImagePipeline.shared.clearCache()
        URLCache.shared.removeAllCachedResponses()
        refreshCenter.invalidateSafety()
        await onBlocksChanged?()
    }

    func unblock(userID: UUID) async throws {
        _ = try await apiClient.send(APIRequest<EmptyResponse>(
            method: .delete, path: "me/blocks/\(userID.uuidString)", acceptedStatusCodes: [204]
        ))
        knownBlockIDs?.remove(userID)
        refreshCenter.invalidateAll()
        await onBlocksChanged?()
    }

    func report(reviewID: UUID, reviewType: String) async throws {
        _ = try await apiClient.send(APIRequest<EmptyResponse>(
            method: .post, path: "reports",
            body: .json(AnyEncodable(ReportPayload(reviewType: reviewType, reviewId: reviewID))),
            acceptedStatusCodes: [202]
        ))
    }

    func synchronizeBlocks() async {
        guard let users = try? await fetchBlockedUsers() else { return }
        let current = Set(users.map(\.id))
        if let previous = knownBlockIDs, previous != current {
            RemoteImagePipeline.shared.clearCache()
            URLCache.shared.removeAllCachedResponses()
            refreshCenter.invalidateSafety()
            await onBlocksChanged?()
        }
        knownBlockIDs = current
    }

    func reset() { knownBlockIDs = nil }
}
