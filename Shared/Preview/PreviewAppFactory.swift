import Foundation
import SwiftData

enum PreviewSessionMode {
    case signedIn
    case signedOut
}

@MainActor
enum PreviewAppFactory {
    static func makeContainer(session: PreviewSessionMode = .signedIn) -> AppContainer {
        let container = AppContainer(inMemory: true)
        let seeded = seed(container: container)

        switch session {
        case .signedIn:
            container.sessionStore.setPreviewState(.signedIn(seeded.currentUser))
        case .signedOut:
            container.sessionStore.setPreviewState(.signedOut)
        }

        return container
    }

    static func samplePlace(in container: AppContainer) -> Place {
        let descriptor = FetchDescriptor<Place>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return (try? container.persistenceController.mainContext.fetch(descriptor).first) ?? Place(
            name: "Preview Place",
            latitude: 37.7749,
            longitude: -122.4194,
            address: "1 Market St, San Francisco, CA",
            sourceType: .appleMaps
        )
    }

    static func samplePeople() -> [FilterPerson] {
        [
            FilterPerson(id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!, name: "Me", isCurrentUser: true),
            FilterPerson(id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!, name: "Alice", isCurrentUser: false),
            FilterPerson(id: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!, name: "Bob", isCurrentUser: false)
        ]
    }

    private static func seed(container: AppContainer) -> SeededPreviewData {
        let context = container.persistenceController.mainContext

        let me = User(
            id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            appleUserId: "preview.me",
            displayName: "Taylor",
            bio: "Collecting private favorites from friends."
        )
        let alice = User(
            id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
            appleUserId: "preview.alice",
            displayName: "Alice",
            bio: "Always knows the best pasta."
        )
        let bob = User(
            id: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!,
            appleUserId: "preview.bob",
            displayName: "Bob",
            bio: "Dessert-first reviewer."
        )

        let place = Place(
            id: UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!,
            appleMapsPlaceId: "preview-place-1",
            name: "Caffè Aurora",
            latitude: 37.7764,
            longitude: -122.4231,
            address: "123 Valencia St, San Francisco, CA",
            sourceType: .appleMaps,
            createdByUserId: me.id
        )
        let secondPlace = Place(
            id: UUID(uuidString: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE")!,
            appleMapsPlaceId: "preview-place-2",
            name: "Sunset BBQ",
            latitude: 37.7687,
            longitude: -122.4295,
            address: "456 Divisadero St, San Francisco, CA",
            sourceType: .appleMaps,
            createdByUserId: alice.id
        )

        let category = CustomCategory(
            id: UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!,
            ownerUserId: me.id,
            name: "BBQ Spots",
            iconName: "flame"
        )
        let categoryAssignment = PlaceCategoryAssignment(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            placeId: secondPlace.id,
            categoryId: category.id,
            assignedByUserId: me.id
        )

        let friendRelation = FriendRelation(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            ownerUserId: me.id,
            targetUserId: alice.id,
            status: .accepted
        )
        let pendingRelation = FriendRelation(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            ownerUserId: bob.id,
            targetUserId: me.id,
            status: .pending
        )

        let myReview = PlaceReview(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            placeId: place.id,
            authorUserId: me.id,
            ratingOverall: 9,
            reviewText: "Reliable brunch spot",
            descriptionText: "Great coffee, quick service, and plenty of seating."
        )
        let friendReview = PlaceReview(
            id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
            placeId: secondPlace.id,
            authorUserId: alice.id,
            ratingOverall: 8,
            reviewText: "Worth the queue",
            descriptionText: "Smoked ribs and house pickles are the move."
        )

        let dishReview = DishReview(
            id: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
            placeId: place.id,
            authorUserId: me.id,
            placeReviewId: myReview.id,
            dishName: "Tiramisu Pancakes",
            dishRating: 10,
            dishReviewText: "Ridiculously good mascarpone cream.",
            price: 14
        )

        let placeActivity = ActivityItem(
            id: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
            actorUserId: alice.id,
            type: .placeReviewAdded,
            referenceId: friendReview.id.uuidString
        )
        let dishActivity = ActivityItem(
            id: UUID(uuidString: "88888888-8888-8888-8888-888888888888")!,
            actorUserId: me.id,
            type: .dishReviewAdded,
            referenceId: dishReview.id.uuidString
        )

        context.insert(me)
        context.insert(alice)
        context.insert(bob)
        context.insert(place)
        context.insert(secondPlace)
        context.insert(category)
        context.insert(categoryAssignment)
        context.insert(friendRelation)
        context.insert(pendingRelation)
        context.insert(myReview)
        context.insert(friendReview)
        context.insert(dishReview)
        context.insert(placeActivity)
        context.insert(dishActivity)

        try? context.save()

        return SeededPreviewData(
            currentUser: me,
            place: place
        )
    }
}

private struct SeededPreviewData {
    let currentUser: User
    let place: Place
}
