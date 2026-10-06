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

            CommandMenu("Navigate") {
                Button("Map") {
                    container.selectedTab = .map
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Places") {
                    container.selectedTab = .places
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("Add Review") {
                    container.selectedTab = .add
                }
                .keyboardShortcut("3", modifiers: .command)

                Button("Activity") {
                    container.selectedTab = .feed
                }
                .keyboardShortcut("4", modifiers: .command)

                Button("Profile") {
                    container.selectedTab = .profile
                }
                .keyboardShortcut("5", modifiers: .command)
            }

            CommandGroup(after: .appSettings) {
                Button("Refresh") {
                    container.refreshCenter.invalidateAll()
                }
                .keyboardShortcut("r", modifiers: .command)
            }

            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    container.isSettingsPresented = true
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
        #endif
    }
}
