import Foundation
import SwiftData

@MainActor
final class PersistenceController {
    let modelContainer: ModelContainer

    init(inMemory: Bool = false) {
        let configuration = ModelConfiguration(
            "TrustMap",
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: .none
        )

        do {
            modelContainer = try ModelContainer(
                for: User.self,
                FriendInvite.self,
                Friendship.self,
                Place.self,
                PlaceReview.self,
                DishReview.self,
                PhotoAsset.self,
                CustomCategory.self,
                PlaceCategoryAssignment.self,
                ActivityItem.self,
                configurations: configuration
            )
        } catch {
            fatalError("Failed to create SwiftData container: \(error.localizedDescription)")
        }
    }

    var mainContext: ModelContext {
        modelContainer.mainContext
    }
}
