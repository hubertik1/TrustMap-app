import SwiftUI

struct AppRootView: View {
    @Environment(\.scenePhase) private var scenePhase

    @ObservedObject private var container: AppContainer
    @ObservedObject private var preferencesStore: AppPreferencesStore
    @ObservedObject private var sessionStore: SessionStore
    @ObservedObject private var refreshCenter: AppRefreshCenter

    init(container: AppContainer) {
        self.container = container
        self.preferencesStore = container.preferencesStore
        self.sessionStore = container.sessionStore
        self.refreshCenter = container.refreshCenter
    }

    var body: some View {
        Group {
            switch sessionStore.state {
            case .launching:
                LoadingStateView(title: L10n.preparingTrustmap)

            case .signedOut:
                WelcomeView(
                    viewModel: WelcomeViewModel(
                        sessionStore: sessionStore,
                        authService: container.authService
                    )
                )

            case .signedIn:
                MainTabView(container: container)
                    .id(refreshCenter.safetyRevision)
            }
        }
        .preferredColorScheme(preferencesStore.preferredColorScheme)
        .trustMapMacWindowConfigurator()
        .task {
            if case .launching = sessionStore.state {
                await sessionStore.bootstrap()
            }
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await sessionStore.handleSceneDidBecomeActive()
            await container.notificationPermissionCoordinator.handleAppDidBecomeActive()
            guard signedInUserID != nil else { return }
            await container.safetyRepository.synchronizeBlocks()
            await container.notificationBadgeStore.loadUnreadCount()
        }
        .task(id: signedInUserID) {
            if signedInUserID == nil {
                container.notificationBadgeStore.reset()
            } else {
                await container.safetyRepository.synchronizeBlocks()
                container.notificationPermissionCoordinator.requestOnboardingNotificationPermissionIfNeeded()
                container.pushDeviceTokenManager.uploadCurrentDeviceTokenIfPossible()
                await container.notificationBadgeStore.loadUnreadCount()
            }
        }
        .alert(
            "TrustMap",
            isPresented: Binding(
                get: { sessionStore.alertMessage != nil },
                set: { if !$0 { sessionStore.alertMessage = nil } }
            )
        ) {
            Button(L10n.ok, role: .cancel) {}
        } message: {
            Text(sessionStore.alertMessage ?? "")
        }
    }

    private var signedInUserID: UUID? {
        sessionStore.currentUser?.id
    }
}

#Preview("Signed In") {
    AppRootView(container: PreviewAppFactory.makeContainer())
}

#Preview("Signed Out") {
    AppRootView(container: PreviewAppFactory.makeContainer(session: .signedOut))
}
