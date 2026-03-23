import Foundation

@MainActor
final class AddHubViewModel: ObservableObject {
    enum Flow: Identifiable {
        case placeReview
        case dishReview

        var id: String {
            switch self {
            case .placeReview:
                return "placeReview"
            case .dishReview:
                return "dishReview"
            }
        }

        var title: String {
            switch self {
            case .placeReview:
                return "Add Place Review"
            case .dishReview:
                return "Add Dish Review"
            }
        }
    }

    @Published private(set) var recentPlaces: [Place] = []
    @Published var errorMessage: String?

    private let placeRepository: PlaceRepository

    init(placeRepository: PlaceRepository) {
        self.placeRepository = placeRepository
    }

    func load() async {
        do {
            recentPlaces = try placeRepository.recentPlaces()
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
        }
    }
}
