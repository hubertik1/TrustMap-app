import Foundation
import OSLog

@MainActor
protocol PushDeviceTokenHandling: AnyObject {
    func handleRegisteredDeviceToken(_ token: String)
    func handleRemoteNotificationRegistrationFailure(_ error: Error)
}

@MainActor
final class PushDeviceTokenBridge {
    static let shared = PushDeviceTokenBridge()

    private var handler: PushDeviceTokenHandling?
    private var pendingDeviceToken: String?
    private let logger = Logger(subsystem: "TrustMap", category: "PushDeviceTokenBridge")

    private init() {}

    func configure(handler: PushDeviceTokenHandling?) {
        self.handler = handler

        guard let pendingDeviceToken, let handler else {
            return
        }

        self.pendingDeviceToken = nil
        handler.handleRegisteredDeviceToken(pendingDeviceToken)
    }

    func receiveDeviceToken(_ token: String) {
        guard let handler else {
            pendingDeviceToken = token
            return
        }

        handler.handleRegisteredDeviceToken(token)
    }

    func receiveRegistrationFailure(_ error: Error) {
        logger.warning("Remote notification registration failed: \(error.localizedDescription, privacy: .public)")
        handler?.handleRemoteNotificationRegistrationFailure(error)
    }
}
