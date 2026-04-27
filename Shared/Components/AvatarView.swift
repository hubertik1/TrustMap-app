import SwiftUI
import UIKit

struct AvatarView: View {
    let name: String
    var avatarURL: URL? = nil
    var size: CGFloat = 40
    var allowsFullscreen = true

    @State private var loadedImage: UIImage?
    @State private var isLoading = false
    @State private var isPresentingFullscreenAvatar = false

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
            } else if isLoading && !previewCandidateURLs.isEmpty {
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
        .contentShape(Circle())
        .accessibilityHidden(true)
        .task(id: requestCacheKey) {
            await loadImage()
        }
        .highPriorityGesture(
            TapGesture().onEnded {
                guard allowsFullscreen, avatarURL != nil else {
                    return
                }

                isPresentingFullscreenAvatar = true
            }
        )
        .fullScreenCover(isPresented: $isPresentingFullscreenAvatar) {
            AvatarLightboxView(
                name: name,
                fallbackAvatar: AnyView(
                    fallbackAvatar
                        .frame(width: min(UIScreen.main.bounds.width * 0.55, 220), height: min(UIScreen.main.bounds.width * 0.55, 220))
                ),
                candidateURLs: fullscreenCandidateURLs
            )
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

    private var previewCandidateURLs: [URL] {
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

    private var fullscreenCandidateURLs: [URL] {
        guard let avatarURL else {
            return []
        }

        let original = avatarURL
        guard let originalString = normalizedURLString(from: avatarURL),
              let derivedMedium = derivedVariantURL(from: originalString, suffix: "-medium") else {
            return [original]
        }

        return uniqueURLs([derivedMedium, original])
    }

    private var requestCacheKey: String {
        let urls = previewCandidateURLs
            .map(\.absoluteString)
            .joined(separator: "|")
        let pixelSize = Int(max(1, size.rounded(.up)))
        return "avatar|\(pixelSize)x\(pixelSize)|\(urls)"
    }

    @MainActor
    private func loadImage() async {
        guard !previewCandidateURLs.isEmpty else {
            loadedImage = nil
            isLoading = false
            return
        }

        let targetSize = CGSize(width: max(size, 1), height: max(size, 1))
        isLoading = true

        do {
            loadedImage = try await RemoteImagePipeline.shared.loadImage(
                candidateURLs: previewCandidateURLs,
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

private struct AvatarLightboxView: View {
    @Environment(\.dismiss) private var dismiss

    let name: String
    let fallbackAvatar: AnyView
    let candidateURLs: [URL]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            RemoteURLImageView(
                candidateURLs: candidateURLs,
                contentMode: .fit,
                targetDisplaySize: UIScreen.main.bounds.size
            ) {
                VStack(spacing: 20) {
                    fallbackAvatar
                    Text(name)
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()

            Button("Done") {
                dismiss()
            }
            .padding(.top, 16)
            .padding(.trailing, 16)
            .foregroundStyle(.white)
        }
    }
}

private struct RemoteURLImageView<Placeholder: View>: View {
    let candidateURLs: [URL]
    var contentMode: ContentMode = .fill
    var targetDisplaySize = CGSize(width: 96, height: 96)
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var loadedImage: UIImage?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let loadedImage {
                configuredImage(Image(uiImage: loadedImage).resizable())
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                placeholder()
            }
        }
        .task(id: requestCacheKey) {
            await loadImage()
        }
    }

    private var requestCacheKey: String {
        let urls = candidateURLs
            .map(\.absoluteString)
            .joined(separator: "|")
        let width = Int(max(1, targetDisplaySize.width.rounded(.up)))
        let height = Int(max(1, targetDisplaySize.height.rounded(.up)))
        return "remote-url-image|\(width)x\(height)|\(urls)"
    }

    @ViewBuilder
    private func configuredImage(_ image: Image) -> some View {
        switch contentMode {
        case .fill:
            image
                .scaledToFill()
        case .fit:
            image
                .scaledToFit()
        }
    }

    @MainActor
    private func loadImage() async {
        guard !candidateURLs.isEmpty else {
            loadedImage = nil
            isLoading = false
            return
        }

        isLoading = true

        do {
            loadedImage = try await RemoteImagePipeline.shared.loadImage(
                candidateURLs: candidateURLs,
                cacheKey: requestCacheKey as NSString,
                targetDisplaySize: CGSize(
                    width: max(targetDisplaySize.width, 1),
                    height: max(targetDisplaySize.height, 1)
                ),
                screenScale: UIScreen.main.scale
            )
        } catch is CancellationError {
            return
        } catch {
            loadedImage = nil
        }

        isLoading = false
    }
}

#Preview {
    AvatarView(name: "Taylor Morgan", size: 56)
}
