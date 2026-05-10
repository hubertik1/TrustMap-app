import SwiftUI

@main
struct TrustMapApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var container: AppContainer

    init() {
        _container = StateObject(wrappedValue: AppContainer())
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(container: container)
        }
    }
}
