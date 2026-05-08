import Foundation
import XCTest
@testable import TrustMapContractSupport

final class BackendContractTests: XCTestCase {
    private var originalAPIBaseURL: String?
    private var originalEnvironmentName: String?

    override func setUp() {
        super.setUp()

        originalAPIBaseURL = ProcessInfo.processInfo.environment["TRUSTMAP_API_BASE_URL"]
        originalEnvironmentName = ProcessInfo.processInfo.environment["TRUSTMAP_ENVIRONMENT_NAME"]

        setenv("TRUSTMAP_API_BASE_URL", "http://127.0.0.1:5104", 1)
        setenv("TRUSTMAP_ENVIRONMENT_NAME", "Local", 1)
    }

    override func tearDown() {
        restoreEnvironmentVariable("TRUSTMAP_API_BASE_URL", originalValue: originalAPIBaseURL)
        restoreEnvironmentVariable("TRUSTMAP_ENVIRONMENT_NAME", originalValue: originalEnvironmentName)
        super.tearDown()
    }

    @MainActor
    func testAPIClientRefreshesSessionAfterUnauthorized() async throws {
        let firstResponse = makeUserResponse(displayName: "Hubert")
        let refreshedResponse = makeUserResponse(displayName: "Hubert")
        let sessionProvider = MockSessionProvider(accessToken: "expired-token", refreshedAccessToken: "fresh-token")
        let protocolState = URLProtocolState(
            responses: [
                .unauthorized,
                .json(statusCode: 200, body: firstResponse)
            ]
        )

        let apiClient = makeAPIClient(protocolState: protocolState)
        apiClient.sessionProvider = sessionProvider

        let response = try await apiClient.send(
            APIRequest<User>(
                method: .get,
                path: "me"
            )
        )

        XCTAssertEqual(response.displayName, "Hubert")
        let refreshCallCount = sessionProvider.refreshCallCount
        XCTAssertEqual(refreshCallCount, 1)

        let requests = await protocolState.requests
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests.first?.value(forHTTPHeaderField: "Authorization"), "Bearer expired-token")
        XCTAssertEqual(requests.last?.value(forHTTPHeaderField: "Authorization"), "Bearer fresh-token")
        XCTAssertEqual(refreshedResponse, firstResponse)
    }

    @MainActor
    func testFriendRepositoryMapsFriendsResponse() async throws {
        let friendId = UUID(uuidString: "C5B43D5F-14FB-4E83-B5A5-0CC4B394B095")!
        let response = """
        [
          {
            "user": {
              "id": "\(friendId.uuidString.lowercased())",
              "handle": "friend.one#1234",
              "displayName": "Friend One",
              "avatarUrl": null
            },
            "friendsSinceUtc": "2026-04-07T12:00:00Z"
          }
        ]
        """

        let (apiClient, sessionProvider) = makeAuthorizedClient(json: response)
        _ = sessionProvider
        let repository = FriendRepository(apiClient: apiClient)
        let friends = try await repository.fetchFriends()

        XCTAssertEqual(friends.count, 1)
        XCTAssertEqual(friends[0].id, friendId)
        XCTAssertEqual(friends[0].user.handle, "friend.one#1234")
        XCTAssertEqual(friends[0].createdAt, iso8601("2026-04-07T12:00:00Z"))
    }

    @MainActor
    func testFriendRepositoryFetchesUserFriendsWithRelationshipStatus() async throws {
        let friendId = UUID(uuidString: "C5B43D5F-14FB-4E83-B5A5-0CC4B394B095")!
        let ownerId = UUID(uuidString: "7AD7BF4A-7D7C-4DDE-92CA-A6C4B635C922")!
        let response = """
        [
          {
            "user": {
              "id": "\(friendId.uuidString.lowercased())",
              "handle": "friend.one#1234",
              "displayName": "Friend One",
              "avatarUrl": null
            },
            "friendsSinceUtc": "2026-04-07T12:00:00Z",
            "relationshipStatus": "OutgoingRequest"
          }
        ]
        """

        let protocolState = URLProtocolState(responses: [.json(statusCode: 200, body: response)])
        let (apiClient, sessionProvider) = makeAuthorizedClient(protocolState: protocolState)
        _ = sessionProvider
        let repository = FriendRepository(apiClient: apiClient)
        let friends = try await repository.fetchFriends(of: ownerId)

        XCTAssertEqual(friends.count, 1)
        XCTAssertEqual(friends[0].id, friendId)
        XCTAssertEqual(friends[0].relationshipStatus, .outgoingRequest)

        let requests = await protocolState.requests
        XCTAssertEqual(requests.first?.httpMethod, "GET")
        XCTAssertEqual(requests.first?.url?.path, "/users/\(ownerId.uuidString)/friends")
    }

    @MainActor
    func testUserProfileRepositoryUpdatesPrivacySettings() async throws {
        let response = makeUserResponse(
            displayName: "Hubert",
            reviewVisibility: "FriendsOfFriends",
            friendListVisibility: "Private",
            profileVisibility: "Friends",
            profilePictureVisibility: "FriendsOfFriends",
            canViewFriends: true
        )
        let protocolState = URLProtocolState(responses: [.json(statusCode: 200, body: response)])
        let (apiClient, sessionProvider) = makeAuthorizedClient(protocolState: protocolState)
        _ = sessionProvider
        let repository = UserProfileRepository(apiClient: apiClient)

        let updated = try await repository.updatePrivacySettings(
            reviewVisibility: .friendsOfFriends,
            friendListVisibility: .onlyMe,
            profileVisibility: .friendsOnly,
            profilePictureVisibility: .friendsOfFriends
        )

        XCTAssertEqual(updated.reviewVisibility, .friendsOfFriends)
        XCTAssertEqual(updated.friendListVisibility, .onlyMe)
        XCTAssertEqual(updated.profileVisibility, .friendsOnly)
        XCTAssertEqual(updated.profilePictureVisibility, .friendsOfFriends)
        XCTAssertTrue(updated.canViewFriends)

        let requests = await protocolState.requests
        XCTAssertEqual(requests.first?.httpMethod, "PATCH")
        XCTAssertEqual(requests.first?.url?.path, "/me/privacy")
        XCTAssertEqual(requests.first?.value(forHTTPHeaderField: "Content-Type"), "application/json")

        let requestBodies = await protocolState.requestBodies
        let bodyData = try XCTUnwrap(requestBodies.first ?? nil)
        let payload = try JSONDecoder().decode(PrivacySettingsPayloadProbe.self, from: bodyData)
        XCTAssertEqual(payload.reviewVisibility, "FriendsOfFriends")
        XCTAssertEqual(payload.friendListVisibility, "Private")
        XCTAssertEqual(payload.profileVisibility, "Friends")
        XCTAssertEqual(payload.profilePictureVisibility, "FriendsOfFriends")
    }

    func testVisibilityStatusDecodesFriendsOfFriends() throws {
        let status = try JSONDecoder().decode(VisibilityStatus.self, from: Data(#""FriendsOfFriends""#.utf8))

        XCTAssertEqual(status, .friendsOfFriends)
        XCTAssertEqual(status.displayName, "Friends of Friends")
    }

    func testVisibilityStatusDecodesIntegerFriendsOfFriends() throws {
        let status = try JSONDecoder().decode(VisibilityStatus.self, from: Data("4".utf8))

        XCTAssertEqual(status, .friendsOfFriends)
    }

    func testVisibilityStatusEncodesFriendsOfFriendsAsString() throws {
        let data = try JSONEncoder().encode(VisibilityStatus.friendsOfFriends)
        let encoded = String(decoding: data, as: UTF8.self)

        XCTAssertEqual(encoded, #""FriendsOfFriends""#)
    }

    func testVisibilityStatusRejectsInvalidStringAndInteger() {
        XCTAssertThrowsError(try JSONDecoder().decode(VisibilityStatus.self, from: Data(#""Invalid""#.utf8)))
        XCTAssertThrowsError(try JSONDecoder().decode(VisibilityStatus.self, from: Data("99".utf8)))
    }

    func testUserDecodesPrivacyFields() throws {
        let response = makeUserResponse(
            displayName: "Hubert",
            reviewVisibility: "FriendsOfFriends",
            friendListVisibility: "Private",
            profileVisibility: "Friends",
            profilePictureVisibility: "FriendsOfFriends",
            canViewProfile: false,
            canViewFriends: false,
            canViewReviews: false,
            canViewProfilePicture: false
        )

        let user = try JSONDecoder().decode(User.self, from: Data(response.utf8))

        XCTAssertEqual(user.reviewVisibility, .friendsOfFriends)
        XCTAssertEqual(user.friendListVisibility, .onlyMe)
        XCTAssertEqual(user.profileVisibility, .friendsOnly)
        XCTAssertEqual(user.profilePictureVisibility, .friendsOfFriends)
        XCTAssertFalse(user.canViewProfile)
        XCTAssertFalse(user.canViewFriends)
        XCTAssertFalse(user.canViewReviews)
        XCTAssertFalse(user.canViewProfilePicture)
        XCTAssertTrue(user.supportsPrivacySettings)
    }

    func testUserDecodingDefaultsMissingPrivacyFields() throws {
        let response = makeUserResponse(
            displayName: "Hubert",
            includesPrivacyFields: false
        )

        let user = try JSONDecoder().decode(User.self, from: Data(response.utf8))

        XCTAssertEqual(user.reviewVisibility, .friendsOnly)
        XCTAssertEqual(user.friendListVisibility, .friendsOnly)
        XCTAssertEqual(user.profileVisibility, .public)
        XCTAssertEqual(user.profilePictureVisibility, .public)
        XCTAssertTrue(user.canViewProfile)
        XCTAssertTrue(user.canViewFriends)
        XCTAssertTrue(user.canViewReviews)
        XCTAssertTrue(user.canViewProfilePicture)
        XCTAssertFalse(user.supportsPrivacySettings)
    }

    func testUserDecodingDefaultsMissingCanViewReviews() throws {
        let response = makeUserResponse(
            displayName: "Hubert",
            includesCanViewReviews: false
        )

        let user = try JSONDecoder().decode(User.self, from: Data(response.utf8))

        XCTAssertTrue(user.canViewReviews)
        XCTAssertTrue(user.supportsPrivacySettings)
    }

    func testProfileStatDisplayShowsPrivateReviewStats() {
        let places = ProfileStatDisplay.places(count: 12, canViewReviews: false)
        let dishes = ProfileStatDisplay.dishes(count: 8, canViewReviews: false)

        XCTAssertEqual(places.value, "Private")
        XCTAssertTrue(places.isPrivate)
        XCTAssertEqual(dishes.value, "Private")
        XCTAssertTrue(dishes.isPrivate)
    }

    func testProfileStatDisplayShowsReviewCountsWhenVisible() {
        let places = ProfileStatDisplay.places(count: 0, canViewReviews: true)
        let dishes = ProfileStatDisplay.dishes(count: 3, canViewReviews: true)

        XCTAssertEqual(places.value, "0")
        XCTAssertFalse(places.isPrivate)
        XCTAssertEqual(dishes.value, "3")
        XCTAssertFalse(dishes.isPrivate)
    }

    func testUserReviewsPrivacyFallbackCopyMatchesExpectedMessage() {
        XCTAssertEqual(ProfileReviewPrivacyContent.title, "Reviews are private")
        XCTAssertEqual(
            ProfileReviewPrivacyContent.message,
            "This user doesn’t allow you to view their rated places or reviewed dishes."
        )
    }

    func testUserDecodesPrivateProfileDtoWithNilAvatar() throws {
        let response = makeUserResponse(
            displayName: "Hubert",
            avatarUrl: nil,
            canViewProfile: false,
            canViewFriends: false,
            canViewProfilePicture: false
        )

        let user = try JSONDecoder().decode(User.self, from: Data(response.utf8))

        XCTAssertFalse(user.canViewProfile)
        XCTAssertFalse(user.canViewProfilePicture)
        XCTAssertNil(user.avatarURL)
    }

    func testHandleComponentsSplitCanonicalHandle() {
        let components = HandleComponents(handle: "friend.one#1234")

        XCTAssertEqual(components.base, "friend.one")
        XCTAssertEqual(components.suffix, "#1234")
    }

    func testHandleComponentsKeepLegacyHandleWithoutSuffix() {
        let components = HandleComponents(handle: "legacy-handle")

        XCTAssertEqual(components.base, "legacy-handle")
        XCTAssertEqual(components.suffix, "")
    }

    func testHandleComponentsNormalizeEditableBaseFromDecoratedHandle() {
        let normalized = HandleComponents.normalizedEditableBase(from: " @hubert#1234 ")

        XCTAssertEqual(normalized, "hubert")
    }

    func testHandleComponentsNormalizeEditableBaseDropsLeadingAtSign() {
        let normalized = HandleComponents.normalizedEditableBase(from: "@hubert")

        XCTAssertEqual(normalized, "hubert")
    }

    @MainActor
    func testFeedRepositoryMapsDishAndPlaceActivities() async throws {
        let response = """
        {
          "items": [
            {
              "activityType": "DishReview",
              "itemId": "7AD7BF4A-7D7C-4DDE-92CA-A6C4B635C922",
              "visibility": "Friends",
              "createdAtUtc": "2026-04-07T12:00:00Z",
              "updatedAtUtc": "2026-04-07T12:30:00Z",
              "author": {
                "id": "C5B43D5F-14FB-4E83-B5A5-0CC4B394B095",
                "handle": "friend.one#1234",
                "displayName": "Friend One",
                "avatarUrl": null
              },
              "place": {
                "id": "9F6E8AA6-9BFA-4E63-BCA3-1ED12E904C7D",
                "name": "Meme Bistro",
                "address": "Main Street 1",
                "city": "Warsaw",
                "countryCode": "PL",
                "latitude": 52.2297,
                "longitude": 21.0122
              },
              "rating": 5,
              "body": "Great",
              "title": null,
              "dishName": "Ramen",
              "photos": []
            },
            {
              "activityType": "PlaceReview",
              "itemId": "65F10D68-6B25-4F2E-9F5F-D44B7E7B4EE7",
              "visibility": "Public",
              "createdAtUtc": "2026-04-07T13:00:00Z",
              "updatedAtUtc": "2026-04-07T13:05:00Z",
              "author": {
                "id": "6D78503B-757D-4A2E-9215-A79C0F38B52A",
                "handle": "friend.two#5678",
                "displayName": "Friend Two",
                "avatarUrl": null
              },
              "place": {
                "id": "0D31AE2F-B36B-4336-B723-B2A4B8A8577D",
                "name": "Cafe Uno",
                "address": "Market Square 2",
                "city": "Krakow",
                "countryCode": "PL",
                "latitude": 50.0647,
                "longitude": 19.9450
              },
              "rating": 4,
              "body": "Nice",
              "title": "Solid coffee",
              "dishName": null,
              "photos": []
            }
          ],
          "nextCursorUtc": null
        }
        """

        let (apiClient, sessionProvider) = makeAuthorizedClient(json: response)
        _ = sessionProvider
        let repository = FeedRepository(apiClient: apiClient)
        let items = try await repository.fetchFeed()

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].activityKind, .dishReview)
        XCTAssertEqual(items[0].author.displayName, "Friend One")
        XCTAssertEqual(items[0].place.displayName, "Meme Bistro")
        XCTAssertEqual(items[0].dishName, "Ramen")
        XCTAssertEqual(items[0].body, "Great")
        XCTAssertNil(items[0].title)
        XCTAssertTrue(items[0].photos.isEmpty)
        XCTAssertEqual(items[1].activityKind, .placeReview)
        XCTAssertEqual(items[1].author.displayName, "Friend Two")
        XCTAssertEqual(items[1].place.displayName, "Cafe Uno")
        XCTAssertEqual(items[1].title, "Solid coffee")
        XCTAssertEqual(items[1].body, "Nice")
        XCTAssertEqual(items[1].createdAt, iso8601("2026-04-07T13:05:00Z"))
    }

    @MainActor
    func testAPIClientDecodesBackendDateWithoutTimezoneSuffix() async throws {
        struct TimestampProbe: Decodable {
            let createdAtUtc: Date
        }

        let protocolState = URLProtocolState(
            responses: [
                .json(
                    statusCode: 200,
                    body: """
                    {
                      "createdAtUtc": "2026-04-07T13:00:00.123456"
                    }
                    """
                )
            ]
        )

        let apiClient = makeAPIClient(protocolState: protocolState)
        let probe = try await apiClient.send(
            APIRequest<TimestampProbe>(
                method: .get,
                path: "probe",
                requiresAuthorization: false
            )
        )

        XCTAssertGreaterThan(probe.createdAtUtc.timeIntervalSince1970, 0)
    }

    @MainActor
    func testPhotoUploadResponseDecodesCreatedAtUtc() async throws {
        let protocolState = URLProtocolState(
            responses: [
                .json(
                    statusCode: 201,
                    body: """
                    {
                      "id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
                      "url": "/uploads/reviews/photo-1.jpg",
                      "contentType": "image/jpeg",
                      "sizeBytes": 12345,
                      "width": 1440,
                      "height": 1080,
                      "mediumUrl": "/uploads/reviews/photo-1-medium.jpg",
                      "thumbnailUrl": "/uploads/reviews/photo-1-thumb.jpg",
                      "createdAtUtc": "2026-04-08T12:00:00Z"
                    }
                    """
                )
            ]
        )

        let apiClient = makeAPIClient(protocolState: protocolState)
        let asset = try await apiClient.send(
            APIRequest<PhotoAsset>(
                method: .post,
                path: "photos/upload",
                requiresAuthorization: false,
                acceptedStatusCodes: [201]
            )
        )

        XCTAssertEqual(asset.url, "/uploads/reviews/photo-1.jpg")
        XCTAssertEqual(asset.mediumURLString, "/uploads/reviews/photo-1-medium.jpg")
        XCTAssertEqual(asset.thumbnailURLString, "/uploads/reviews/photo-1-thumb.jpg")
        XCTAssertEqual(asset.createdAt, iso8601("2026-04-08T12:00:00Z"))
    }

    @MainActor
    func testAPIClientMapsProblemDetailsValidationError() async throws {
        let protocolState = URLProtocolState(
            responses: [
                .json(
                    statusCode: 422,
                    body: """
                    {
                      "title": "Validation failed",
                      "status": 422,
                      "errors": {
                        "handle": ["Handle is already taken."]
                      }
                    }
                    """
                )
            ]
        )

        let (apiClient, sessionProvider) = makeAuthorizedClient(protocolState: protocolState)
        _ = sessionProvider

        do {
            _ = try await apiClient.send(
                APIRequest<User>(
                    method: .get,
                    path: "me"
                )
            )
            XCTFail("Expected validation failure")
        } catch let error as AppError {
            switch error {
            case .validationFailure(let message):
                XCTAssertEqual(message, "Handle is already taken.")
            default:
                XCTFail("Unexpected AppError: \(error)")
            }
        }
    }

    func testPhotoAssetResolvesRelativeBackendURL() {
        let asset = PhotoAsset(
            id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            url: "/uploads/reviews/photo-1.jpg"
        )

        XCTAssertEqual(asset.resolvedURL?.absoluteString, "http://127.0.0.1:5104/uploads/reviews/photo-1.jpg")
    }

    func testPhotoAssetFallsBackToOriginalWhenPreferredVariantIsMissing() {
        let asset = PhotoAsset(
            id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            url: "/uploads/reviews/photo-1.jpg",
            thumbnailURLString: nil,
            mediumURLString: "/uploads/reviews/photo-1-medium.jpg"
        )

        XCTAssertEqual(
            asset.resolvedURLs(for: .thumbnail).map(\.absoluteString),
            [
                "http://127.0.0.1:5104/uploads/reviews/photo-1-medium.jpg",
                "http://127.0.0.1:5104/uploads/reviews/photo-1.jpg"
            ]
        )
    }

    func testUserSummaryResolvesRelativeAvatarURL() {
        let user = UserSummary(
            id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
            handle: "hubert#1234",
            displayName: "Hubert",
            avatarURLString: "/avatars/hubert.jpg"
        )

        XCTAssertEqual(user.avatarURL?.absoluteString, "http://127.0.0.1:5104/avatars/hubert.jpg")
    }

    func testMapPlaceDecodesSearchTextAndFallsBackWhenMissing() throws {
        let mapPlaces = try JSONDecoder().decode([MapPlace].self, from: Data("""
        [
          {
            "placeId": "9F6E8AA6-9BFA-4E63-BCA3-1ED12E904C7D",
            "name": "IKEA",
            "displayName": "IKEA",
            "customDisplayName": null,
            "sourceType": "ProviderVenue",
            "address": "Main Street 1",
            "city": "Warsaw",
            "countryCode": "PL",
            "latitude": 50.0,
            "longitude": 19.0,
            "createdByUserId": null,
            "categoryNames": ["Restaurants"],
            "visiblePlaceReviewCount": 1,
            "visibleDishReviewCount": 1,
            "averagePlaceRating": 5,
            "contributorCount": 1,
            "latestActivityAtUtc": 0,
            "recentContributors": [],
            "isReviewedByCurrentUser": true,
            "searchText": "Hot dog crispy and cheap"
          },
          {
            "placeId": "0D31AE2F-B36B-4336-B723-B2A4B8A8577D",
            "name": "Old Backend Place",
            "displayName": "Old Backend Place",
            "customDisplayName": null,
            "sourceType": "ProviderVenue",
            "address": "Market Square 2",
            "city": "Krakow",
            "countryCode": "PL",
            "latitude": 50.1,
            "longitude": 19.1,
            "createdByUserId": null,
            "categoryNames": [],
            "visiblePlaceReviewCount": 1,
            "visibleDishReviewCount": 0,
            "averagePlaceRating": 4,
            "contributorCount": 1,
            "latestActivityAtUtc": 0,
            "recentContributors": []
          }
        ]
        """.utf8))

        XCTAssertEqual(mapPlaces[0].searchText, "Hot dog crispy and cheap")
        XCTAssertTrue(mapPlaces[0].isReviewedByCurrentUser)
        XCTAssertEqual(mapPlaces[1].searchText, "")
        XCTAssertFalse(mapPlaces[1].isReviewedByCurrentUser)
    }

    func testPlaceListSearchMatchesBackendSearchTextAndTokens() {
        let item = PlaceListItem(
            id: UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!,
            place: Place(
                id: UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!,
                name: "Nowe zoo",
                latitude: 50.0,
                longitude: 19.0,
                address: "Zoo Street 1",
                city: "Poznań",
                countryCode: "PL"
            ),
            averageRating: 5,
            reviewCount: 2,
            contributorCount: 1,
            recentContributors: [],
            latestActivityAtUtc: Date(timeIntervalSinceReferenceDate: 0),
            categoryNames: ["Restaurants"],
            reviewerRatings: [],
            createdByUserId: nil,
            isReviewedByCurrentUser: false,
            searchText: "Fajne danie Hot dog Cafés crispy and cheap"
        )

        XCTAssertTrue(PlaceListSearch.matches(query: "hot dog", item: item))
        XCTAssertTrue(PlaceListSearch.matches(query: "nowe fajne", item: item))
        XCTAssertTrue(PlaceListSearch.matches(query: "restaurants", item: item))
        XCTAssertTrue(PlaceListSearch.matches(query: "cafe", item: item))
        XCTAssertFalse(PlaceListSearch.matches(query: "ramen", item: item))
    }

    func testPlaceListItemMineMatchesCreatedOrReviewedByCurrentUser() {
        let currentUserID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let otherUserID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!

        let createdByCurrentUser = makePlaceListItem(
            id: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!,
            createdByUserId: currentUserID,
            isReviewedByCurrentUser: false
        )
        let reviewedByCurrentUser = makePlaceListItem(
            id: UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!,
            createdByUserId: otherUserID,
            isReviewedByCurrentUser: true
        )
        let otherUserOnly = makePlaceListItem(
            id: UUID(uuidString: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE")!,
            createdByUserId: otherUserID,
            isReviewedByCurrentUser: false
        )
        let legacyUnknownAuthor = makePlaceListItem(
            id: UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!,
            createdByUserId: nil,
            isReviewedByCurrentUser: false
        )

        XCTAssertTrue(createdByCurrentUser.isMine(currentUserID: currentUserID))
        XCTAssertTrue(reviewedByCurrentUser.isMine(currentUserID: currentUserID))
        XCTAssertFalse(otherUserOnly.isMine(currentUserID: currentUserID))
        XCTAssertFalse(legacyUnknownAuthor.isMine(currentUserID: nil))
    }

    private func makePlaceListItem(
        id: UUID,
        createdByUserId: UUID?,
        isReviewedByCurrentUser: Bool
    ) -> PlaceListItem {
        PlaceListItem(
            id: id,
            place: Place(
                id: id,
                name: "Place",
                latitude: 50.0,
                longitude: 19.0,
                address: "Street 1"
            ),
            averageRating: 5,
            reviewCount: 1,
            contributorCount: 1,
            recentContributors: [],
            latestActivityAtUtc: Date(timeIntervalSinceReferenceDate: 0),
            categoryNames: [],
            reviewerRatings: [],
            createdByUserId: createdByUserId,
            isReviewedByCurrentUser: isReviewedByCurrentUser,
            searchText: ""
        )
    }

    @MainActor
    private func makeAuthorizedClient(json: String) -> (APIClient, MockSessionProvider) {
        let protocolState = URLProtocolState(
            responses: [
                .json(statusCode: 200, body: json)
            ]
        )

        return makeAuthorizedClient(protocolState: protocolState)
    }

    @MainActor
    private func makeAuthorizedClient(protocolState: URLProtocolState) -> (APIClient, MockSessionProvider) {
        let apiClient = makeAPIClient(protocolState: protocolState)
        let sessionProvider = MockSessionProvider(accessToken: "test-token", refreshedAccessToken: "test-token")
        apiClient.sessionProvider = sessionProvider
        return (apiClient, sessionProvider)
    }

    @MainActor
    private func makeAPIClient(protocolState: URLProtocolState) -> APIClient {
        MockURLProtocol.state = protocolState

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        return APIClient(
            baseURL: URL(string: "https://trustmap.example")!,
            urlSession: session
        )
    }

    private func makeUserResponse(
        displayName: String,
        avatarUrl: String? = nil,
        reviewVisibility: String = "Friends",
        friendListVisibility: String = "Friends",
        profileVisibility: String = "Public",
        profilePictureVisibility: String = "Public",
        canViewProfile: Bool = true,
        canViewFriends: Bool = true,
        canViewReviews: Bool = true,
        canViewProfilePicture: Bool = true,
        includesPrivacyFields: Bool = true,
        includesCanViewReviews: Bool = true
    ) -> String {
        let avatarValue = avatarUrl.map { "\"\($0)\"" } ?? "null"
        let canViewReviewsField = includesCanViewReviews
            ? """
          "canViewReviews": \(canViewReviews),
        """
            : ""
        let privacyFields = includesPrivacyFields
            ? """
          "reviewVisibility": "\(reviewVisibility)",
          "friendListVisibility": "\(friendListVisibility)",
          "profileVisibility": "\(profileVisibility)",
          "profilePictureVisibility": "\(profilePictureVisibility)",
          "canViewProfile": \(canViewProfile),
          "canViewFriends": \(canViewFriends),
        \(canViewReviewsField)
          "canViewProfilePicture": \(canViewProfilePicture),
        """
            : ""

        return """
        {
          "id": "7AD7BF4A-7D7C-4DDE-92CA-A6C4B635C922",
          "handle": "hubert#1234",
          "displayName": "\(displayName)",
          "bio": null,
          "avatarUrl": \(avatarValue),
          "relationshipStatus": "Self",
          "friendCount": 3,
          "visiblePlaceReviewCount": 5,
          "visibleDishReviewCount": 8,
        \(privacyFields)
          "isMe": true
        }
        """
    }

    private func iso8601(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }

    private func restoreEnvironmentVariable(_ name: String, originalValue: String?) {
        if let originalValue {
            setenv(name, originalValue, 1)
        } else {
            unsetenv(name)
        }
    }
}

private actor URLProtocolState {
    enum StubbedResponse {
        case unauthorized
        case json(statusCode: Int, body: String)
    }

    private(set) var requests: [URLRequest] = []
    private(set) var requestBodies: [Data?] = []
    private var responses: [StubbedResponse]

    init(responses: [StubbedResponse]) {
        self.responses = responses
    }

    func nextResponse(for request: URLRequest) -> (HTTPURLResponse, Data) {
        requests.append(request)
        requestBodies.append(Self.bodyData(from: request))

        let stub = responses.removeFirst()
        switch stub {
        case .unauthorized:
            return (
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: 401,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!,
                Data("{}".utf8)
            )

        case .json(let statusCode, let body):
            return (
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: statusCode,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!,
                Data(body.utf8)
            )
        }
    }

    private static func bodyData(from request: URLRequest) -> Data? {
        if let httpBody = request.httpBody {
            return httpBody
        }

        guard let stream = request.httpBodyStream else {
            return nil
        }

        stream.open()
        defer { stream.close() }

        var data = Data()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while true {
            let readCount = stream.read(buffer, maxLength: bufferSize)
            if readCount > 0 {
                data.append(buffer, count: readCount)
            } else {
                break
            }
        }

        return data
    }
}

private struct PrivacySettingsPayloadProbe: Decodable {
    let reviewVisibility: String
    let friendListVisibility: String
    let profileVisibility: String
    let profilePictureVisibility: String
}

private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var state: URLProtocolState?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let state = Self.state else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        Task {
            let (response, data) = await state.nextResponse(for: request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}

@MainActor
private final class MockSessionProvider: APISessionProviding {
    private(set) var accessToken: String
    private let refreshedAccessToken: String
    private(set) var refreshCallCount = 0

    init(accessToken: String, refreshedAccessToken: String) {
        self.accessToken = accessToken
        self.refreshedAccessToken = refreshedAccessToken
    }

    var currentAccessToken: String? {
        accessToken
    }

    func refreshSession() async throws -> String {
        refreshCallCount += 1
        accessToken = refreshedAccessToken
        return refreshedAccessToken
    }

    func handleUnauthorizedSession() async {}
}
