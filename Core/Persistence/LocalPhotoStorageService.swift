import Foundation

@MainActor
final class LocalPhotoStorageService {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func storeImageData(_ data: Data) throws -> String {
        let reference = "\(UUID().uuidString).jpg"
        let url = fileURL(for: reference)

        if !fileManager.fileExists(atPath: baseDirectory.path) {
            try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        }

        try data.write(to: url, options: .atomic)
        return reference
    }

    func imageData(for reference: String) -> Data? {
        try? Data(contentsOf: fileURL(for: reference))
    }

    func deleteImageIfPresent(for reference: String) {
        let url = fileURL(for: reference)
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }

        try? fileManager.removeItem(at: url)
    }

    func fileURL(for reference: String) -> URL {
        baseDirectory.appendingPathComponent(reference)
    }

    private var baseDirectory: URL {
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return applicationSupport.appendingPathComponent("TrustMapPhotos", isDirectory: true)
    }
}
