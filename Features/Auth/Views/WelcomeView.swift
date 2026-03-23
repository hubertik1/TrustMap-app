import AuthenticationServices
import SwiftUI

struct WelcomeView: View {
    @StateObject private var viewModel: WelcomeViewModel

    init(viewModel: WelcomeViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                Spacer()

                VStack(alignment: .leading, spacing: 12) {
                    Text("TrustMap")
                        .font(.largeTitle.weight(.bold))

                    Text("TrustMap: Your Friends’ Favorite Spots")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    Text("Keep a private map of places, dishes, and reviews that only you and your accepted friends can see.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 16) {
                    Label("Browse Apple Maps and rate places from 1 to 10.", systemImage: "mappin.and.ellipse")
                    Label("Track dish-level reviews with photos and notes.", systemImage: "fork.knife")
                    Label("See only trusted recommendations from friends you accept.", systemImage: "person.2.badge.gearshape")
                }
                .font(.subheadline)

                Spacer()

                SignInWithAppleButton(.continue) { request in
                    viewModel.configure(request)
                } onCompletion: { result in
                    Task {
                        await viewModel.handleSignInCompletion(result)
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 52)
                .disabled(viewModel.isSigningIn || AppConfiguration.isRunningPreviews)

                if AppConfiguration.isRunningPreviews {
                    Text("Sign in with Apple is unavailable inside SwiftUI previews. Run TrustMap in the Simulator or on a device to test authentication.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    let container = PreviewAppFactory.makeContainer(session: .signedOut)
    WelcomeView(
        viewModel: WelcomeViewModel(
            sessionStore: container.sessionStore,
            authService: container.authService
        )
    )
}
