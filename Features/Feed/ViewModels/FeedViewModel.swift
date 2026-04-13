import Foundation
import OSLog

@MainActor
final class FeedViewModel: ObservableObject {
    @Published private(set) var feedItems: [FeedPlaceActivityItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let logger = Logger(subsystem: "TrustMap", category: "FeedViewModel")
    private let feedRepository: FeedRepository

    init(feedRepository: FeedRepository) {
        self.feedRepository = feedRepository
    }

    func load() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            feedItems = try await feedRepository.fetchFeed()
            errorMessage = nil
        } catch {
            guard !Self.isCancellation(error) else { return }
            logger.error("Unable to load feed: \(error.localizedDescription, privacy: .public)")
            errorMessage = AppError.wrap(error).errorDescription
            feedItems = []
        }
    }

    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }
}
