import Foundation

enum PhotoAssetVariant: String, CaseIterable, Sendable {
    case thumbnail
    case medium
    case original
}

struct PhotoAsset: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let url: String
    let contentType: String
    let sizeBytes: Int64
    let width: Int?
    let height: Int?
    let thumbnailURLString: String?
    let mediumURLString: String?
    let createdAt: Date

    private enum CodingKeys: String, CodingKey {
        case id
        case url
        case contentType
        case sizeBytes
        case width
        case height
        case thumbnailURLString = "thumbnailUrl"
        case mediumURLString = "mediumUrl"
        case createdAt = "createdAtUtc"
    }

    init(
        id: UUID = UUID(),
        url: String,
        contentType: String = "image/jpeg",
        sizeBytes: Int64 = 0,
        width: Int? = nil,
        height: Int? = nil,
        thumbnailURLString: String? = nil,
        mediumURLString: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.url = url
        self.contentType = contentType
        self.sizeBytes = sizeBytes
        self.width = width
        self.height = height
        self.thumbnailURLString = thumbnailURLString
        self.mediumURLString = mediumURLString
        self.createdAt = createdAt
    }

    var resolvedURL: URL? {
        resolvedURL(for: .original)
    }

    func resolvedURL(for variant: PhotoAssetVariant) -> URL? {
        resolvedURLs(for: variant).first
    }

    func resolvedURLs(for variant: PhotoAssetVariant) -> [URL] {
        let candidateStrings: [String?] = switch variant {
        case .thumbnail:
            [thumbnailURLString, mediumURLString, url]
        case .medium:
            [mediumURLString, url]
        case .original:
            [url]
        }

        var seen = Set<String>()
        return candidateStrings
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
            .compactMap(AppConfiguration.resolvedBackendURL(from:))
    }
}
