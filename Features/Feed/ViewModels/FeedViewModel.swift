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

        do {
            feedItems = try await feedRepository.fetchFeed()
        } catch {
            logger.error("Unable to load feed: \(error.localizedDescription, privacy: .public)")
            errorMessage = AppError.wrap(error).errorDescription
            feedItems = []
        }

        isLoading = false
    }
}
