import SwiftUI
import UIKit

struct AvatarView: View {
    let name: String
    var avatarURL: URL? = nil
    var size: CGFloat = 40

    @State private var loadedImage: UIImage?
    @State private var isLoading = false

    private var initials: String {
        let parts = name.split(separator: " ")
        let characters = parts.prefix(2).compactMap(\.first)
        return characters.isEmpty ? "TM" : String(characters)
    }

    var body: some View {
        Group {
            if let loadedImage {
                Image(uiImage: loadedImage)
                    .resizable()
                    .scaledToFill()
            } else if isLoading && !candidateURLs.isEmpty {
                fallbackAvatar
                    .overlay {
                        ProgressView()
                            .controlSize(.small)
                    }
            } else {
                fallbackAvatar
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
        .task(id: requestCacheKey) {
            await loadImage()
        }
    }

    private var fallbackAvatar: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.15))

            Text(initials.uppercased())
                .font(.system(size: size * 0.36, weight: .semibold))
                .foregroundStyle(Color.accentColor)
        }
    }

    private var candidateURLs: [URL] {
        guard let avatarURL else {
            return []
        }

        let original = avatarURL
        guard let originalString = normalizedURLString(from: avatarURL),
              let derivedMedium = derivedVariantURL(from: originalString, suffix: "-medium"),
              let derivedThumbnail = derivedVariantURL(from: originalString, suffix: "-thumb") else {
            return [original]
        }

        return uniqueURLs([derivedThumbnail, derivedMedium, original])
    }

    private var requestCacheKey: String {
        let urls = candidateURLs
            .map(\.absoluteString)
            .joined(separator: "|")
        let pixelSize = Int(max(1, size.rounded(.up)))
        return "avatar|\(pixelSize)x\(pixelSize)|\(urls)"
    }

    @MainActor
    private func loadImage() async {
        guard !candidateURLs.isEmpty else {
            loadedImage = nil
            isLoading = false
            return
        }

        let targetSize = CGSize(width: max(size, 1), height: max(size, 1))
        isLoading = true

        do {
            loadedImage = try await RemoteImagePipeline.shared.loadImage(
                candidateURLs: candidateURLs,
                cacheKey: requestCacheKey as NSString,
                targetDisplaySize: targetSize,
                screenScale: UIScreen.main.scale
            )
        } catch is CancellationError {
            return
        } catch {
            loadedImage = nil
        }

        isLoading = false
    }

    private func normalizedURLString(from url: URL) -> String? {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.query = nil
        components?.fragment = nil
        return components?.string
    }

    private func derivedVariantURL(from originalString: String, suffix: String) -> URL? {
        guard let originalURL = URL(string: originalString) else {
            return nil
        }

        let pathExtension = originalURL.pathExtension
        guard !pathExtension.isEmpty else {
            return nil
        }

        let basePath = String(originalURL.deletingPathExtension().absoluteString)
        return URL(string: "\(basePath)\(suffix).jpg")
    }

    private func uniqueURLs(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        return urls.filter { seen.insert($0.absoluteString).inserted }
    }
}

#Preview {
    AvatarView(name: "Taylor Morgan", size: 56)
}
