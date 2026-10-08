import SwiftUI

struct BlockUserButton: View {
    let user: UserSummary
    let repository: SafetyRepository
    @State private var showsConfirmation = false
    @State private var isBlocking = false
    @State private var errorMessage: String?

    var body: some View {
        Menu {
            Button(L10n.blockUser, systemImage: "person.crop.circle.badge.xmark", role: .destructive) {
                showsConfirmation = true
            }
        } label: {
            Label(L10n.profileActions, systemImage: "ellipsis")
                .foregroundStyle(.secondary)
        }
        .tint(.red)
        .disabled(isBlocking)
        .confirmationDialog(L10n.blockValue(String(describing: user.displayName)), isPresented: $showsConfirmation, titleVisibility: .visible) {
            Button(L10n.blockUser, role: .destructive) {
                Task {
                    isBlocking = true
                    defer { isBlocking = false }
                    do { try await repository.block(userID: user.id) }
                    catch { errorMessage = AppError.wrap(error).errorDescription }
                }
            }
        } message: {
            Text(L10n.youWonTSeeEachOtherSContentOrReceiveFriendRequestsYourFriendshipWillBeRemoved)
        }
        .alert(L10n.couldnTBlockUser, isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) {} message: {
            Text(errorMessage ?? L10n.pleaseTryAgain)
        }
    }
}
