import SwiftUI
import UIKit

enum TrustMapPlatform {
    static var isMacCatalyst: Bool {
        #if targetEnvironment(macCatalyst)
        return true
        #else
        return false
        #endif
    }

    @MainActor
    static var screenScale: CGFloat {
        UIScreen.main.scale
    }
}

enum TrustMapSystemSettings {
    static var appSettingsURL: URL? {
        URL(string: UIApplication.openSettingsURLString)
    }

    static var notificationSettingsURL: URL? {
        if #available(iOS 16.0, *) {
            return URL(string: UIApplication.openNotificationSettingsURLString)
        }

        return nil
    }

    @MainActor
    static func openAppSettings() {
        guard let appSettingsURL else { return }
        UIApplication.shared.open(appSettingsURL)
    }

    @MainActor
    static func openNotificationSettings() {
        guard let fallbackURL = appSettingsURL else { return }

        guard let notificationSettingsURL else {
            UIApplication.shared.open(fallbackURL)
            return
        }

        UIApplication.shared.open(notificationSettingsURL) { success in
            guard !success else { return }
            Task { @MainActor in
                UIApplication.shared.open(fallbackURL)
            }
        }
    }
}
