import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel

    init(container: AppContainer) {
        _viewModel = StateObject(
            wrappedValue: SettingsViewModel(sessionStore: container.sessionStore)
        )
    }

    var body: some View {
        Form {
            Section("Account") {
                Text("TrustMap uses Sign in with Apple only for v1.")
                Button("Sign Out", role: .destructive) {
                    viewModel.signOut()
                }
            }

            Section("Privacy") {
                Text("All reviews, dish notes, and uploaded photos stay private to accepted friends.")
                Text("Nothing in TrustMap is public by default.")
            }

            Section("App") {
                Text("TrustMap: Your Friends’ Favorite Spots")
                Text(viewModel.buildSummary)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SettingsView(container: PreviewAppFactory.makeContainer())
    }
}
