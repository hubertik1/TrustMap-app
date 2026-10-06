import SwiftUI

struct BlockUserButton: View {
    let user: UserSummary
    let repository: SafetyRepository
    @State private var showsConfirmation = false
    @State private var isBlocking = false
    @State private var errorMessage: String?

    var body: some View {
        Menu {
            Button("Block User", systemImage: "person.crop.circle.badge.xmark", role: .destructive) {
                showsConfirmation = true
            }
        } label: {
            Label("Profile actions", systemImage: "ellipsis")
                .foregroundStyle(.secondary)
        }
        .tint(.red)
        .disabled(isBlocking)
        .confirmationDialog("Block \(user.displayName)?", isPresented: $showsConfirmation, titleVisibility: .visible) {
            Button("Block User", role: .destructive) {
                Task {
                    isBlocking = true
                    defer { isBlocking = false }
                    do { try await repository.block(userID: user.id) }
                    catch { errorMessage = AppError.wrap(error).errorDescription }
                }
            }
        } message: {
            Text("You won't see each other's content or receive friend requests. Your friendship will be removed.")
        }
        .alert("Couldn't Block User", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) {} message: {
            Text(errorMessage ?? "Please try again.")
        }
    }
}
