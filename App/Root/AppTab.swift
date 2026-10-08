import Foundation

enum AppTab: Hashable {
    case map
    case places
    case add
    case feed
    case profile

    var phoneTitle: String {
        switch self {
        case .map:
            return L10n.map
        case .places:
            return L10n.places
        case .add:
            return L10n.add
        case .feed:
            return L10n.feed
        case .profile:
            return L10n.profile
        }
    }

    var macTitle: String {
        switch self {
        case .map:
            return L10n.map
        case .places:
            return L10n.places
        case .add:
            return L10n.addReview
        case .feed:
            return L10n.activity
        case .profile:
            return L10n.profile
        }
    }

    var systemImage: String {
        switch self {
        case .map:
            return "map"
        case .places:
            return "mappin.and.ellipse"
        case .add:
            return "plus.circle.fill"
        case .feed:
            return "list.bullet.rectangle"
        case .profile:
            return "person.crop.circle"
        }
    }
}
