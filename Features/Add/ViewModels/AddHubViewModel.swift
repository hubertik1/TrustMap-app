import Foundation

@MainActor
final class AddHubViewModel: ObservableObject {
    enum Flow: Identifiable, Equatable {
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
    @Published private(set) var availableCategoryOptions: [PlaceCategoryOption] = [.all]
    @Published var selectedCategory = PlaceCategoryOption.all
    @Published var errorMessage: String?

    private let mapRepository: MapRepository
    private let categoryRepository: CategoryRepository

    init(
        mapRepository: MapRepository,
        categoryRepository: CategoryRepository
    ) {
        self.mapRepository = mapRepository
        self.categoryRepository = categoryRepository
    }

    func load() async {
        do {
            async let categories = categoryRepository.fetchMyCategories()
            async let places = mapRepository.fetchMapPlaces(
                categoryID: selectedCategory.categoryID,
                take: 50
            )

            let resolvedCategories = try await categories
            let resolvedPlaces = try await places

            availableCategoryOptions = [.all] + resolvedCategories.map(PlaceCategoryOption.init(category:))
            if selectedCategory != .all,
               !availableCategoryOptions.contains(selectedCategory) {
                selectedCategory = .all
            }

            recentPlaces = resolvedPlaces.map(\.place)
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
        }
    }

    func applyCategoryFilter(_ option: PlaceCategoryOption) async {
        guard selectedCategory != option else {
            return
        }

        selectedCategory = option
        await load()
    }
}
