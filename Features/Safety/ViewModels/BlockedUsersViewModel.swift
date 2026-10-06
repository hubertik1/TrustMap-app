import Foundation

@MainActor
final class BlockedUsersViewModel: ObservableObject {
    @Published private(set) var users: [BlockedUser] = []
    @Published private(set) var isLoading = false
    @Published private(set) var unblockingID: UUID?
    @Published var errorMessage: String?
    private let repository: SafetyRepository

    init(repository: SafetyRepository) { self.repository = repository }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do { users = try await repository.fetchBlockedUsers() }
        catch {
            guard !(error is CancellationError) else { return }
            errorMessage = AppError.wrap(error).errorDescription
        }
    }

    func unblock(_ user: BlockedUser) async {
        guard unblockingID == nil else { return }
        unblockingID = user.id
        errorMessage = nil
        defer { unblockingID = nil }
        do {
            try await repository.unblock(userID: user.id)
            users.removeAll { $0.id == user.id }
        } catch { errorMessage = AppError.wrap(error).errorDescription }
    }
}
