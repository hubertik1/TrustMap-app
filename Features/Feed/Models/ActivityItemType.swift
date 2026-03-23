import Foundation

enum ActivityItemType: String, Codable, CaseIterable, Identifiable {
    case placeReviewAdded
    case dishReviewAdded
    case photoAdded

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .placeReviewAdded:
            return "Place Review"
        case .dishReviewAdded:
            return "Dish Review"
        case .photoAdded:
            return "Photo"
        }
    }
}
