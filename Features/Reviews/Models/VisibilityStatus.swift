import Foundation

enum VisibilityStatus: String, Codable, CaseIterable, Identifiable {
    case friendsOnly = "Friends"
    case friendsOfFriends = "FriendsOfFriends"
    case onlyMe = "Private"
    case `public` = "Public"

    static var allCases: [VisibilityStatus] {
        [.public, .friendsOfFriends, .friendsOnly, .onlyMe]
    }

    static let reviewPrivacyOptions: [VisibilityStatus] = [.public, .friendsOfFriends, .friendsOnly]
    static let friendListPrivacyOptions: [VisibilityStatus] = [.public, .friendsOfFriends, .friendsOnly, .onlyMe]
    static let profilePrivacyOptions: [VisibilityStatus] = [.public, .friendsOfFriends, .friendsOnly]
    static let profilePicturePrivacyOptions: [VisibilityStatus] = [.public, .friendsOfFriends, .friendsOnly]

    var id: String { rawValue }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let stringValue = try? container.decode(String.self) {
            switch stringValue {
            case Self.friendsOnly.rawValue:
                self = .friendsOnly
            case Self.friendsOfFriends.rawValue:
                self = .friendsOfFriends
            case Self.onlyMe.rawValue:
                self = .onlyMe
            case Self.public.rawValue:
                self = .public
            default:
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid visibility value: \(stringValue)"
                )
            }
            return
        }

        if let integerValue = try? container.decode(Int.self) {
            switch integerValue {
            case 1:
                self = .onlyMe
            case 2:
                self = .friendsOnly
            case 3:
                self = .public
            case 4:
                self = .friendsOfFriends
            default:
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid visibility value: \(integerValue)"
                )
            }
            return
        }

        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Visibility value must be a string or integer"
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var displayName: String {
        switch self {
        case .friendsOnly:
            return "Friends Only"
        case .friendsOfFriends:
            return "Friends of Friends"
        case .onlyMe:
            return "Only Me"
        case .public:
            return "Everyone"
        }
    }

    var selectableValue: VisibilityStatus {
        switch self {
        case .onlyMe:
            return .friendsOnly
        case .friendsOnly, .friendsOfFriends, .public:
            return self
        }
    }
}
