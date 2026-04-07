import SwiftUI

@main
struct TrustMapApp: App {
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
