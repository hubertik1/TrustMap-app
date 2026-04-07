import Foundation

enum PreviewSessionMode {
    case signedIn
    case signedOut
}

@MainActor
enum PreviewAppFactory {
    static func makeContainer(session: PreviewSessionMode = .signedIn) -> AppContainer {
        let container = AppContainer(preview: true)

        switch session {
        case .signedIn:
            container.sessionStore.setPreviewState(.signedIn(sampleUser))
        case .signedOut:
            container.sessionStore.setPreviewState(.signedOut)
        }

        return container
    }

    static func samplePlace(in container: AppContainer) -> Place {
        _ = container
        return Place(
            id: UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!,
            name: "Caffe Aurora",
            latitude: 37.7764,
            longitude: -122.4231,
            address: "123 Valencia St, San Francisco, CA",
            city: "San Francisco",
            countryCode: "US"
        )
    }

    static func samplePeople() -> [FilterPerson] {
        [
            FilterPerson(id: sampleUser.id, name: sampleUser.displayName, isCurrentUser: true),
            FilterPerson(id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!, name: "Alice", isCurrentUser: false),
            FilterPerson(id: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!, name: "Bob", isCurrentUser: false)
        ]
    }

    static let sampleUser = User(
        id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
        handle: "taylor",
        displayName: "Taylor",
        bio: "Collecting private favorites from friends.",
        relationshipStatus: .self,
        friendCount: 2,
        visiblePlaceReviewCount: 4,
        visibleDishReviewCount: 3,
        isMe: true
    )
}
