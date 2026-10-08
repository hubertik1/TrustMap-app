import SwiftUI

@main
struct TrustMapApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var container: AppContainer

    init() {
        _container = StateObject(wrappedValue: AppContainer())
    }

    var body: some Scene {
        WindowGroup("TrustMap") {
            AppRootView(container: container)
        }
        #if targetEnvironment(macCatalyst)
        .commands {
            SidebarCommands()

            CommandMenu(L10n.navigate) {
                Button(L10n.map) {
                    container.selectedTab = .map
                }
                .keyboardShortcut("1", modifiers: .command)

                Button(L10n.places) {
                    container.selectedTab = .places
                }
                .keyboardShortcut("2", modifiers: .command)

                Button(L10n.addReview) {
                    container.selectedTab = .add
                }
                .keyboardShortcut("3", modifiers: .command)

                Button(L10n.activity) {
                    container.selectedTab = .feed
                }
                .keyboardShortcut("4", modifiers: .command)

                Button(L10n.profile) {
                    container.selectedTab = .profile
                }
                .keyboardShortcut("5", modifiers: .command)
            }

            CommandGroup(after: .appSettings) {
                Button(L10n.refresh) {
                    container.refreshCenter.invalidateAll()
                }
                .keyboardShortcut("r", modifiers: .command)
            }

            CommandGroup(replacing: .appSettings) {
                Button(L10n.settingsMenu) {
                    container.isSettingsPresented = true
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
        #endif
    }
}
