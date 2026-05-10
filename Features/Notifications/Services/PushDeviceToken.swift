import Foundation

extension Data {
    var trustMapAPNsDeviceTokenHexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
