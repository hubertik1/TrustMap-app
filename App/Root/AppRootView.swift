import SwiftUI

struct AppRootView: View {
    @ObservedObject private var container: AppContainer
    @ObservedObject private var deepLinkRouter: DeepLinkRouter
    @ObservedObject private var sessionStore: SessionStore

    init(container: AppContainer) {
        self.container = container
        self.deepLinkRouter = container.deepLinkRouter
        self.sessionStore = container.sessionStore
    }

    var body: some View {
        Group {
            switch sessionStore.state {
            case .launching:
                LoadingStateView(title: "Preparing TrustMap")

            case .signedOut:
                WelcomeView(
                    viewModel: WelcomeViewModel(
                        sessionStore: sessionStore,
                        authService: container.authService
                    )
                )

            case .signedIn:
                MainTabView(container: container)
            }
        }
        .task {
            if case .launching = sessionStore.state {
                await sessionStore.bootstrap()
            }
        }
        .task(id: sessionStore.currentUser?.id) {
            deepLinkRouter.resumePendingInviteIfNeeded(isAuthenticated: sessionStore.currentUser != nil)

            guard let currentUser = sessionStore.currentUser else {
                return
            }

            let friends =
                (try? await container.friendRepository.acceptedFriends(for: currentUser.id))
                ?? (try? container.friendRepository.cachedAcceptedFriends(for: currentUser.id))
                ?? []

            await container.cloudKitSyncService.refreshFriendVisibleContentIfPossible(
                for: currentUser,
                friends: friends
            )
        }
        .onOpenURL { url in
            deepLinkRouter.handleIncomingURL(url, isAuthenticated: sessionStore.currentUser != nil)
        }
        .alert(
            "TrustMap",
            isPresented: Binding(
                get: { sessionStore.alertMessage != nil },
                set: { if !$0 { sessionStore.alertMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(sessionStore.alertMessage ?? "")
        }
    }
}

#Preview("Signed In") {
    AppRootView(container: PreviewAppFactory.makeContainer())
}

#Preview("Signed Out") {
    AppRootView(container: PreviewAppFactory.makeContainer(session: .signedOut))
}
