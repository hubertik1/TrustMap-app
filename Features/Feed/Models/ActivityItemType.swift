import Foundation

enum ActivityItemType: String, Codable, CaseIterable, Identifiable {
    case placeReviewAdded
    case dishReviewAdded
    case photoAdded

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .placeReviewAdded:
            return L10n.placeReview
        case .dishReviewAdded:
            return L10n.dishReview
        case .photoAdded:
            return L10n.photo
        }
    }
}
