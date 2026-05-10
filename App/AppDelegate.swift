import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.trustMapAPNsDeviceTokenHexString
        Task { @MainActor in
            PushDeviceTokenBridge.shared.receiveDeviceToken(token)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            PushDeviceTokenBridge.shared.receiveRegistrationFailure(error)
        }
    }
}
