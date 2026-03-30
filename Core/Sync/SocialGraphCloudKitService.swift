import CloudKit
import Foundation
import OSLog

@MainActor
protocol SocialGraphCloudKitServicing: AnyObject {
    func fetchUser(id: UUID) async throws -> User?
    func fetchUsers(ids: Set<UUID>) async throws -> [User]
    func upsertUser(_ user: User) async throws
    func fetchPendingIncomingInvites(for userID: UUID) async throws -> [FriendInvite]
    func fetchPendingOutgoingInvites(for userID: UUID) async throws -> [FriendInvite]
    func fetchInvite(token: String) async throws -> FriendInvite?
    func upsertInvite(_ invite: FriendInvite) async throws
    func fetchFriendships(for userID: UUID) async throws -> [Friendship]
    func fetchFriendship(firstUserID: UUID, secondUserID: UUID) async throws -> Friendship?
    func upsertFriendship(_ friendship: Friendship) async throws
}

@MainActor
final class SocialGraphCloudKitService: SocialGraphCloudKitServicing {
    private enum RecordType {
        static let user = "User"
        static let friendInvite = "FriendInvite"
        static let friendship = "Friendship"
    }

    private enum FieldKey {
        static let userID = "id"
        static let appleUserID = "appleUserId"
        static let displayName = "displayName"
        static let bio = "bio"
        static let avatarReference = "avatarReference"
        static let createdAt = "createdAt"
        static let token = "token"
        static let inviterUserID = "inviterUserId"
        static let inviteeUserID = "inviteeUserId"
        static let status = "status"
        static let expiresAt = "expiresAt"
        static let respondedAt = "respondedAt"
        static let userAID = "userAId"
        static let userBID = "userBId"
    }

    private let logger = Logger(subsystem: "TrustMap", category: "SocialCloudKit")
    private let forceDisabled: Bool
    private let container: CKContainer

    init(forceDisabled: Bool = false, container: CKContainer = .default()) {
        self.forceDisabled = forceDisabled
        self.container = container
    }

    private var database: CKDatabase? {
        guard !forceDisabled else {
            return nil
        }

        return container.publicCloudDatabase
    }

    func fetchUser(id: UUID) async throws -> User? {
        guard let database else {
            return nil
        }

        let recordID = CKRecord.ID(recordName: id.uuidString)

        do {
            let record = try await fetchRecord(in: database, with: recordID)
            return record.flatMap(user(from:))
        } catch {
            throw wrap(error, fallback: "Unable to fetch the requested user.")
        }
    }

    func fetchUsers(ids: Set<UUID>) async throws -> [User] {
        guard let database, !ids.isEmpty else {
            return []
        }

        do {
            let records = try await fetchRecords(
                in: database,
                with: ids.map { CKRecord.ID(recordName: $0.uuidString) }
            )
            return records.compactMap(user(from:))
        } catch {
            throw wrap(error, fallback: "Unable to fetch people from iCloud.")
        }
    }

    func upsertUser(_ user: User) async throws {
        guard let database else {
            return
        }

        do {
            let recordID = CKRecord.ID(recordName: user.id.uuidString)
            let record = try await fetchOrCreateRecord(in: database, type: RecordType.user, recordID: recordID)
            record[FieldKey.userID] = user.id.uuidString as CKRecordValue
            record[FieldKey.appleUserID] = user.appleUserId as CKRecordValue
            record[FieldKey.displayName] = user.displayName as CKRecordValue
            record[FieldKey.bio] = user.bio as CKRecordValue?
            record[FieldKey.avatarReference] = user.avatarReference as CKRecordValue?
            record[FieldKey.createdAt] = user.createdAt as CKRecordValue
            _ = try await saveRecord(in: database, record: record)
        } catch {
            throw wrap(error, fallback: "Unable to update your profile in iCloud.")
        }
    }

    func fetchPendingIncomingInvites(for userID: UUID) async throws -> [FriendInvite] {
        try await fetchInvites(
            predicate: NSPredicate(
                format: "%K == %@ AND %K == %@",
                FieldKey.inviteeUserID,
                userID.uuidString,
                FieldKey.status,
                FriendInviteStatus.pending.rawValue
            )
        )
    }

    func fetchPendingOutgoingInvites(for userID: UUID) async throws -> [FriendInvite] {
        try await fetchInvites(
            predicate: NSPredicate(
                format: "%K == %@ AND %K == %@",
                FieldKey.inviterUserID,
                userID.uuidString,
                FieldKey.status,
                FriendInviteStatus.pending.rawValue
            )
        )
    }

    func fetchInvite(token: String) async throws -> FriendInvite? {
        guard !token.isEmpty else {
            return nil
        }

        let invites = try await fetchInvites(
            predicate: NSPredicate(format: "%K == %@", FieldKey.token, token),
            resultsLimit: 1
        )
        return invites.first
    }

    func upsertInvite(_ invite: FriendInvite) async throws {
        guard let database else {
            return
        }

        do {
            let recordID = CKRecord.ID(recordName: invite.id.uuidString)
            let record = try await fetchOrCreateRecord(in: database, type: RecordType.friendInvite, recordID: recordID)
            record[FieldKey.token] = invite.token as CKRecordValue
            record[FieldKey.inviterUserID] = invite.inviterUserId.uuidString as CKRecordValue
            record[FieldKey.inviteeUserID] = invite.inviteeUserId?.uuidString as CKRecordValue?
            record[FieldKey.status] = invite.status.rawValue as CKRecordValue
            record[FieldKey.createdAt] = invite.createdAt as CKRecordValue
            record[FieldKey.expiresAt] = invite.expiresAt as CKRecordValue?
            record[FieldKey.respondedAt] = invite.respondedAt as CKRecordValue?
            _ = try await saveRecord(in: database, record: record)
        } catch {
            throw wrap(error, fallback: "Unable to update the friend invite in iCloud.")
        }
    }

    func fetchFriendships(for userID: UUID) async throws -> [Friendship] {
        guard database != nil else {
            return []
        }

        do {
            let userARecords = try await fetchRecords(
                recordType: RecordType.friendship,
                predicate: NSPredicate(
                    format: "%K == %@",
                    FieldKey.userAID,
                    userID.uuidString
                )
            )
            let userBRecords = try await fetchRecords(
                recordType: RecordType.friendship,
                predicate: NSPredicate(
                    format: "%K == %@",
                    FieldKey.userBID,
                    userID.uuidString
                )
            )
            let mergedRecords = Dictionary(
                uniqueKeysWithValues: (userARecords + userBRecords).map { ($0.recordID.recordName, $0) }
            ).values

            return mergedRecords
                .compactMap(friendship(from:))
                .sorted { $0.createdAt > $1.createdAt }
        } catch {
            if isMissingSchemaError(
                error,
                recordType: RecordType.friendship,
                fieldNames: [
                    FieldKey.userAID,
                    FieldKey.userBID,
                    FieldKey.createdAt
                ]
            ) {
                return []
            }
            throw wrap(error, fallback: "Unable to refresh friendships from iCloud.")
        }
    }

    func fetchFriendship(firstUserID: UUID, secondUserID: UUID) async throws -> Friendship? {
        guard let database else {
            return nil
        }

        let ordered = orderedPair(firstUserID, secondUserID)
        let recordID = CKRecord.ID(recordName: friendshipRecordName(firstUserID: ordered.0, secondUserID: ordered.1))

        do {
            let record = try await fetchRecord(in: database, with: recordID)
            return record.flatMap(friendship(from:))
        } catch {
            throw wrap(error, fallback: "Unable to check the friendship status in iCloud.")
        }
    }

    func upsertFriendship(_ friendship: Friendship) async throws {
        guard let database else {
            return
        }

        do {
            let ordered = orderedPair(friendship.userAId, friendship.userBId)
            let recordID = CKRecord.ID(recordName: friendshipRecordName(firstUserID: ordered.0, secondUserID: ordered.1))
            let record = try await fetchOrCreateRecord(in: database, type: RecordType.friendship, recordID: recordID)
            record[FieldKey.userID] = friendship.id.uuidString as CKRecordValue
            record[FieldKey.userAID] = ordered.0.uuidString as CKRecordValue
            record[FieldKey.userBID] = ordered.1.uuidString as CKRecordValue
            record[FieldKey.createdAt] = friendship.createdAt as CKRecordValue
            _ = try await saveRecord(in: database, record: record)
        } catch {
            throw wrap(error, fallback: "Unable to save the friendship in iCloud.")
        }
    }

    private func fetchInvites(predicate: NSPredicate, resultsLimit: Int = CKQueryOperation.maximumResults) async throws -> [FriendInvite] {
        guard database != nil else {
            return []
        }

        do {
            let records = try await fetchRecords(
                recordType: RecordType.friendInvite,
                predicate: predicate,
                resultsLimit: resultsLimit,
                sortDescriptors: [NSSortDescriptor(key: FieldKey.createdAt, ascending: false)]
            )
            return records.compactMap(friendInvite(from:))
        } catch {
            if isMissingSchemaError(
                error,
                recordType: RecordType.friendInvite,
                fieldNames: [
                    FieldKey.token,
                    FieldKey.inviterUserID,
                    FieldKey.inviteeUserID,
                    FieldKey.status,
                    FieldKey.createdAt
                ]
            ) {
                return []
            }
            throw wrap(error, fallback: "Unable to refresh friend invites from iCloud.")
        }
    }

    private func fetchRecords(
        recordType: String,
        predicate: NSPredicate,
        resultsLimit: Int = CKQueryOperation.maximumResults,
        sortDescriptors: [NSSortDescriptor] = []
    ) async throws -> [CKRecord] {
        guard let database else {
            return []
        }

        let query = CKQuery(recordType: recordType, predicate: predicate)
        query.sortDescriptors = sortDescriptors
        return try await performQuery(in: database, query: query, resultsLimit: resultsLimit)
    }

    private func user(from record: CKRecord) -> User? {
        guard let appleUserID = record[FieldKey.appleUserID] as? String,
              let displayName = record[FieldKey.displayName] as? String,
              let createdAt = record[FieldKey.createdAt] as? Date else {
            logger.error("Skipping invalid User record: \(record.recordID.recordName, privacy: .public)")
            return nil
        }

        let id = UUID(uuidString: record.recordID.recordName) ?? StableIdentifier.userID(forAppleUserID: appleUserID)
        return User(
            id: id,
            appleUserId: appleUserID,
            displayName: displayName,
            avatarReference: record[FieldKey.avatarReference] as? String,
            bio: record[FieldKey.bio] as? String,
            createdAt: createdAt
        )
    }

    private func friendInvite(from record: CKRecord) -> FriendInvite? {
        guard let token = record[FieldKey.token] as? String,
              let inviterUserIDValue = record[FieldKey.inviterUserID] as? String,
              let inviterUserID = UUID(uuidString: inviterUserIDValue),
              let statusValue = record[FieldKey.status] as? String,
              let status = FriendInviteStatus(rawValue: statusValue),
              let createdAt = record[FieldKey.createdAt] as? Date else {
            logger.error("Skipping invalid FriendInvite record: \(record.recordID.recordName, privacy: .public)")
            return nil
        }

        return FriendInvite(
            id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
            token: token,
            inviterUserId: inviterUserID,
            inviteeUserId: (record[FieldKey.inviteeUserID] as? String).flatMap(UUID.init(uuidString:)),
            status: status,
            createdAt: createdAt,
            expiresAt: record[FieldKey.expiresAt] as? Date,
            respondedAt: record[FieldKey.respondedAt] as? Date
        )
    }

    private func friendship(from record: CKRecord) -> Friendship? {
        guard let userAValue = record[FieldKey.userAID] as? String,
              let userAID = UUID(uuidString: userAValue),
              let userBValue = record[FieldKey.userBID] as? String,
              let userBID = UUID(uuidString: userBValue),
              let createdAt = record[FieldKey.createdAt] as? Date else {
            logger.error("Skipping invalid Friendship record: \(record.recordID.recordName, privacy: .public)")
            return nil
        }

        let id = (record[FieldKey.userID] as? String).flatMap(UUID.init(uuidString:))
            ?? StableIdentifier.friendshipID(firstUserID: userAID, secondUserID: userBID)

        return Friendship(
            id: id,
            userAId: userAID,
            userBId: userBID,
            createdAt: createdAt
        )
    }

    private func fetchOrCreateRecord(in database: CKDatabase, type: String, recordID: CKRecord.ID) async throws -> CKRecord {
        if let existingRecord = try await fetchRecord(in: database, with: recordID) {
            return existingRecord
        }

        return CKRecord(recordType: type, recordID: recordID)
    }

    private func fetchRecord(in database: CKDatabase, with recordID: CKRecord.ID) async throws -> CKRecord? {
        try await withCheckedThrowingContinuation { continuation in
            database.fetch(withRecordID: recordID) { record, error in
                if let ckError = error as? CKError, ckError.code == .unknownItem {
                    continuation.resume(returning: nil)
                    return
                }

                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: record)
                }
            }
        }
    }

    private func fetchRecords(in database: CKDatabase, with recordIDs: [CKRecord.ID]) async throws -> [CKRecord] {
        try await withCheckedThrowingContinuation { continuation in
            database.fetch(withRecordIDs: recordIDs) { result in
                switch result {
                case .success(let recordsByID):
                    let records = recordsByID.values.compactMap { value -> CKRecord? in
                        guard case .success(let record) = value else {
                            return nil
                        }
                        return record
                    }
                    continuation.resume(returning: records)

                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func saveRecord(in database: CKDatabase, record: CKRecord) async throws -> CKRecord {
        try await withCheckedThrowingContinuation { continuation in
            database.save(record) { savedRecord, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let savedRecord {
                    continuation.resume(returning: savedRecord)
                } else {
                    continuation.resume(throwing: AppError.syncFailure("CloudKit did not return the saved record."))
                }
            }
        }
    }

    private func performQuery(in database: CKDatabase, query: CKQuery, resultsLimit: Int) async throws -> [CKRecord] {
        var records: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor?

        repeat {
            let page = try await queryPage(in: database, query: cursor == nil ? query : nil, cursor: cursor, resultsLimit: resultsLimit)
            records.append(contentsOf: page.records)
            cursor = page.cursor
        } while cursor != nil && resultsLimit == CKQueryOperation.maximumResults

        return records
    }

    private func queryPage(
        in database: CKDatabase,
        query: CKQuery?,
        cursor: CKQueryOperation.Cursor?,
        resultsLimit: Int
    ) async throws -> (records: [CKRecord], cursor: CKQueryOperation.Cursor?) {
        try await withCheckedThrowingContinuation { continuation in
            let operation: CKQueryOperation
            if let cursor {
                operation = CKQueryOperation(cursor: cursor)
            } else if let query {
                operation = CKQueryOperation(query: query)
            } else {
                continuation.resume(throwing: AppError.syncFailure("CloudKit query configuration is invalid."))
                return
            }

            var pageRecords: [CKRecord] = []
            operation.resultsLimit = resultsLimit
            operation.recordMatchedBlock = { _, result in
                if case .success(let record) = result {
                    pageRecords.append(record)
                }
            }
            operation.queryResultBlock = { result in
                switch result {
                case .success(let cursor):
                    continuation.resume(returning: (pageRecords, cursor))
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            database.add(operation)
        }
    }

    private func friendshipRecordName(firstUserID: UUID, secondUserID: UUID) -> String {
        let ordered = orderedPair(firstUserID, secondUserID)
        return "friendship-\(ordered.0.uuidString)-\(ordered.1.uuidString)"
    }

    private func orderedPair(_ firstUserID: UUID, _ secondUserID: UUID) -> (UUID, UUID) {
        firstUserID.uuidString < secondUserID.uuidString
            ? (firstUserID, secondUserID)
            : (secondUserID, firstUserID)
    }

    private func wrap(_ error: Error, fallback: String) -> AppError {
        if let ckError = error as? CKError, ckError.code == .notAuthenticated {
            return .syncFailure("Sign in to iCloud on this device to use TrustMap friends.")
        }

        return .syncFailure(AppError.wrap(error).errorDescription ?? fallback)
    }

    private func isMissingSchemaError(_ error: Error, recordType: String, fieldNames: [String] = []) -> Bool {
        let missingTypeMessage = "Did not find record type: \(recordType)"
        let missingFieldMessages = fieldNames.map { "Unknown field '\($0)'" }

        return errorMessages(from: error).contains { message in
            message.localizedCaseInsensitiveContains(missingTypeMessage)
                || missingFieldMessages.contains { missingField in
                    message.localizedCaseInsensitiveContains(missingField)
                }
        }
    }

    private func errorMessages(from error: Error) -> [String] {
        let nsError = error as NSError
        var messages: [String] = [nsError.localizedDescription]

        if let failureReason = nsError.localizedFailureReason {
            messages.append(failureReason)
        }

        if let recoverySuggestion = nsError.localizedRecoverySuggestion {
            messages.append(recoverySuggestion)
        }

        for value in nsError.userInfo.values {
            switch value {
            case let message as String:
                messages.append(message)

            case let nestedError as Error:
                messages.append(contentsOf: errorMessages(from: nestedError))

            case let dictionary as [AnyHashable: Any]:
                messages.append(contentsOf: dictionary.values.compactMap { $0 as? String })

            default:
                continue
            }
        }

        return messages
    }
}
