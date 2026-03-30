import CryptoKit
import Foundation

enum StableIdentifier {
    static func userID(forAppleUserID appleUserID: String) -> UUID {
        uuid(for: "user:\(appleUserID)")
    }

    static func friendshipID(firstUserID: UUID, secondUserID: UUID) -> UUID {
        let ordered = orderedPair(firstUserID, secondUserID)
        return uuid(for: "friendship:\(ordered.0.uuidString)|\(ordered.1.uuidString)")
    }

    private static func uuid(for seed: String) -> UUID {
        let digest = SHA256.hash(data: Data(seed.utf8))
        var bytes = Array(digest.prefix(16))

        // Mark the value as a version 4 / RFC 4122 UUID even though it is deterministic.
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80

        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    private static func orderedPair(_ firstID: UUID, _ secondID: UUID) -> (UUID, UUID) {
        firstID.uuidString < secondID.uuidString ? (firstID, secondID) : (secondID, firstID)
    }
}
