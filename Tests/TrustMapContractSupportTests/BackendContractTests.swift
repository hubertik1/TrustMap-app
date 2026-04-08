import Foundation
import XCTest
@testable import TrustMapContractSupport

final class BackendContractTests: XCTestCase {
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
              "handle": "friend_one",
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
        XCTAssertEqual(friends[0].user.handle, "friend_one")
        XCTAssertEqual(friends[0].createdAt, iso8601("2026-04-07T12:00:00Z"))
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
                "handle": "friend_one",
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
                "handle": "friend_two",
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
        XCTAssertEqual(items[0].title, "Friend One added Ramen at Meme Bistro")
        XCTAssertEqual(items[0].subtitle, "Rated 5/5")
        XCTAssertEqual(items[1].title, "Friend Two added Cafe Uno")
        XCTAssertEqual(items[1].subtitle, "Solid coffee")
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

        XCTAssertEqual(asset.resolvedURL?.absoluteString, "http://127.0.0.1:8080/uploads/reviews/photo-1.jpg")
    }

    func testUserSummaryResolvesRelativeAvatarURL() {
        let user = UserSummary(
            id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
            handle: "hubert",
            displayName: "Hubert",
            avatarURLString: "/avatars/hubert.jpg"
        )

        XCTAssertEqual(user.avatarURL?.absoluteString, "http://127.0.0.1:8080/avatars/hubert.jpg")
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

    private func makeUserResponse(displayName: String) -> String {
        """
        {
          "id": "7AD7BF4A-7D7C-4DDE-92CA-A6C4B635C922",
          "handle": "hubert",
          "displayName": "\(displayName)",
          "bio": null,
          "avatarUrl": null,
          "relationshipStatus": "Self",
          "friendCount": 3,
          "visiblePlaceReviewCount": 5,
          "visibleDishReviewCount": 8,
          "isMe": true
        }
        """
    }

    private func iso8601(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }
}

private actor URLProtocolState {
    enum StubbedResponse {
        case unauthorized
        case json(statusCode: Int, body: String)
    }

    private(set) var requests: [URLRequest] = []
    private var responses: [StubbedResponse]

    init(responses: [StubbedResponse]) {
        self.responses = responses
    }

    func nextResponse(for request: URLRequest) -> (HTTPURLResponse, Data) {
        requests.append(request)

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
