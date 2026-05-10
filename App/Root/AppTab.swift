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
            return "Map"
        case .places:
            return "Places"
        case .add:
            return "Add"
        case .feed:
            return "Feed"
        case .profile:
            return "Profile"
        }
    }

    var macTitle: String {
        switch self {
        case .map:
            return "Map"
        case .places:
            return "Places"
        case .add:
            return "Add Review"
        case .feed:
            return "Activity"
        case .profile:
            return "Profile"
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
