import Foundation

struct PhotoAsset: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let url: String
    let contentType: String
    let sizeBytes: Int64
    let createdAt: Date

    init(
        id: UUID = UUID(),
        url: String,
        contentType: String = "image/jpeg",
        sizeBytes: Int64 = 0,
        createdAt: Date = .now
    ) {
        self.id = id
        self.url = url
        self.contentType = contentType
        self.sizeBytes = sizeBytes
        self.createdAt = createdAt
    }

    var resolvedURL: URL? {
        AppConfiguration.resolvedBackendURL(from: url)
    }
}
