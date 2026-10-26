import AuthenticationServices
import Foundation
import XCTest
@testable import TrustMapContractSupport

@MainActor
final class SessionRestorationTests: XCTestCase {
    func testDemoSignInPersistsNormalSessionAndClearsAppleIdentity() async throws {
        let fixture = makeFixture(responses: [.json(200, sessionJSON), .json(200, sessionJSON)])
        fixture.tokens.tokens = nil
        await fixture.store.bootstrap()
        try await fixture.store.signInToDemo(username: "appreview", password: "test-demo-password")

        XCTAssertEqual(fixture.store.currentUser?.displayName, "Anna")
        XCTAssertEqual(fixture.tokens.tokens?.accessToken, "fresh-access")
        XCTAssertNil(fixture.auth.lastAppleUserID())
        let request = try XCTUnwrap(fixture.scenario.requests.first)
        XCTAssertEqual(request.url?.path, "/auth/demo")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        let body: Data
        if let data = request.httpBody {
            body = data
        } else {
            let stream = try XCTUnwrap(request.httpBodyStream)
            stream.open()
            defer { stream.close() }
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 1024)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                guard count > 0 else { break }
                data.append(contentsOf: buffer.prefix(count))
            }
            body = data
        }
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
        XCTAssertEqual(payload, ["username": "appreview", "password": "test-demo-password"])

        await fixture.store.handleSceneDidBecomeActive()
        let token = try await fixture.store.refreshSession()
        XCTAssertEqual(token, "fresh-access")
        XCTAssertNil(fixture.auth.lastAppleUserID())
        XCTAssertEqual(fixture.scenario.requests.map(\.url?.path), ["/auth/demo", "/auth/refresh"])
    }

    func testRejectedDemoSignInDoesNotCreateSession() async {
        let fixture = makeFixture(responses: [.json(401, "{}")])
        fixture.tokens.tokens = nil
        fixture.auth.appleUserID = nil
        await fixture.store.bootstrap()
        do {
            try await fixture.store.signInToDemo(username: "appreview", password: "wrong")
            XCTFail("Invalid credentials must be rejected")
        } catch {
            XCTAssertEqual(AppError.wrap(error).errorDescription, L10n.demoInvalidCredentials)
            XCTAssertNil(fixture.store.currentUser)
            XCTAssertNil(fixture.tokens.tokens)
            XCTAssertNil(fixture.auth.lastAppleUserID())
        }
    }

    func testWelcomeWarmsBackendOnceWithoutCredentialsOrCachedResponse() async {
        let fixture = makeFixture(responses: [.json(200, "Healthy")])
        fixture.tokens.tokens = nil
        await fixture.store.bootstrap()

        fixture.store.warmUpBackendIfNeeded()
        fixture.store.warmUpBackendIfNeeded()
        await waitForRequests(1, in: fixture.scenario)
        await Task.yield()
        fixture.store.warmUpBackendIfNeeded()
        await Task.yield()

        XCTAssertEqual(fixture.scenario.requests.count, 1)
        let request = fixture.scenario.requests.first
        XCTAssertEqual(request?.url?.path, "/health/live")
        XCTAssertEqual(request?.httpMethod, "GET")
        XCTAssertEqual(request?.timeoutInterval, 45)
        XCTAssertEqual(request?.cachePolicy, .reloadIgnoringLocalCacheData)
        XCTAssertNil(request?.value(forHTTPHeaderField: "Authorization"))
        XCTAssertNil(request?.httpBody)
        XCTAssertNil(fixture.store.alertMessage)
        guard case .signedOut = fixture.store.state else { return XCTFail("Warm-up must not change the welcome screen.") }
    }

    func testPendingWarmupDoesNotDelayAppleSignIn() async {
        let fixture = makeFixture(responses: [.pending, .json(200, sessionJSON)])
        fixture.tokens.tokens = nil
        await fixture.store.bootstrap()
        fixture.store.warmUpBackendIfNeeded()
        await waitForRequests(1, in: fixture.scenario)
        fixture.store.warmUpBackendIfNeeded()

        let started = ContinuousClock.now
        await fixture.store.signIn(with: .failure(URLError(.unknown)))

        XCTAssertLessThan(started.duration(to: .now), .seconds(2))
        XCTAssertEqual(fixture.store.currentUser?.displayName, "Anna")
        XCTAssertEqual(fixture.scenario.requests.map(\.url?.path), ["/health/live", "/auth/apple"])
        XCTAssertEqual(fixture.tokens.tokens?.accessToken, "fresh-access")
        XCTAssertNil(fixture.store.alertMessage)
    }

    func testWarmupConnectionFailureDoesNotShowAlertOrPreventSignIn() async {
        let fixture = makeFixture(responses: [.failure(.cannotConnectToHost), .json(200, sessionJSON)])
        fixture.tokens.tokens = nil
        await fixture.store.bootstrap()
        fixture.store.warmUpBackendIfNeeded()
        await waitForRequests(1, in: fixture.scenario)
        await Task.yield()

        XCTAssertNil(fixture.store.alertMessage)
        guard case .signedOut = fixture.store.state else { return XCTFail("Warm-up failure must keep welcome available.") }
        await fixture.store.signIn(with: .failure(URLError(.unknown)))
        XCTAssertEqual(fixture.store.currentUser?.displayName, "Anna")
        XCTAssertEqual(fixture.scenario.requests.map(\.url?.path), ["/health/live", "/auth/apple"])
    }

    func testWarmupRejectionDoesNotInvalidateSavedCredentials() async {
        let fixture = makeFixture(responses: [.json(200, userJSON), .json(401, "not authorized")])
        await fixture.store.bootstrap()
        fixture.store.setPreviewState(.signedOut)
        fixture.store.warmUpBackendIfNeeded()
        await waitForRequests(2, in: fixture.scenario)
        await Task.yield()

        XCTAssertEqual(fixture.tokens.tokens?.accessToken, "saved-access")
        XCTAssertEqual(fixture.tokens.clearCount, 0)
        XCTAssertNil(fixture.store.alertMessage)
        XCTAssertNil(fixture.scenario.requests.last?.value(forHTTPHeaderField: "Authorization"))
    }

    func testStartupAndRestoredSessionDoNotSendSeparateWarmup() async {
        for expired in [false, true] {
            let fixture = makeFixture(expired: expired, responses: [.json(200, expired ? sessionJSON : userJSON)])
            fixture.store.warmUpBackendIfNeeded()
            await fixture.store.bootstrap()
            fixture.store.warmUpBackendIfNeeded()
            await Task.yield()

            XCTAssertEqual(fixture.scenario.requests.map(\.url?.path), [expired ? "/auth/refresh" : "/me"])
        }
    }

    func testRecoverableStartupErrorDoesNotStartSeparateWarmup() async {
        let fixture = makeFixture(expired: true, responses: [.failure(.timedOut)], timeout: .milliseconds(50))
        await fixture.store.bootstrap()
        fixture.store.warmUpBackendIfNeeded()
        await Task.yield()

        assertRetryState(fixture)
        XCTAssertEqual(fixture.scenario.requests.map(\.url?.path), ["/auth/refresh"])
    }

    func testExpiredAccessTokenRestoresWithOnlyOneRefreshRequest() async {
        let fixture = makeFixture(expired: true, responses: [.json(200, sessionJSON)])
        await fixture.store.bootstrap()

        XCTAssertEqual(fixture.store.currentUser?.displayName, "Anna")
        XCTAssertEqual(fixture.scenario.requests.map(\.url?.path), ["/auth/refresh"])
        XCTAssertEqual(fixture.tokens.tokens?.accessToken, "fresh-access")
        XCTAssertEqual(fixture.tokens.tokens?.refreshToken, "fresh-refresh")
        XCTAssertEqual(fixture.scenario.requests.first?.timeoutInterval, 45)
    }

    func testValidAccessTokenRestoresWithOnlyOneProfileRequest() async {
        let fixture = makeFixture(responses: [.json(200, userJSON)])
        await fixture.store.bootstrap()

        XCTAssertEqual(fixture.store.currentUser?.displayName, "Anna")
        XCTAssertEqual(fixture.scenario.requests.map(\.url?.path), ["/me"])
        XCTAssertEqual(fixture.tokens.tokens?.accessToken, "saved-access")
    }

    func testRefreshTimeoutPreservesSessionAndManualRetrySucceeds() async {
        let fixture = makeFixture(expired: true, responses: [.failure(.timedOut), .json(200, sessionJSON)])
        let originalTokens = fixture.tokens.tokens
        await fixture.store.bootstrap()

        assertRetryState(fixture)
        XCTAssertEqual(fixture.tokens.tokens, originalTokens)
        XCTAssertEqual(fixture.auth.appleUserID, "saved-apple-user")
        XCTAssertEqual(fixture.scenario.requests.count, 1, "A rotating refresh token must not be replayed automatically.")

        await fixture.store.bootstrap()
        XCTAssertEqual(fixture.store.currentUser?.displayName, "Anna")
        XCTAssertEqual(fixture.scenario.requests.map(\.url?.path), ["/auth/refresh", "/auth/refresh"])
        XCTAssertEqual(fixture.tokens.clearCount, 0)
    }

    func testRefreshServerErrorPreservesSessionWithoutDisplayingTechnicalDetails() async {
        let fixture = makeFixture(expired: true, responses: [.json(503, "<html>Azure internal gateway details</html>")])
        await fixture.store.bootstrap()

        assertRetryState(fixture)
        XCTAssertNotNil(fixture.tokens.tokens)
        XCTAssertNil(fixture.store.alertMessage)
        XCTAssertEqual(fixture.scenario.requests.count, 1)
    }

    func testImmediateConnectionFailureKeepsLoadingUntilStartupGracePeriodEnds() async {
        let fixture = makeFixture(expired: true, responses: [.failure(.cannotConnectToHost)], timeout: .milliseconds(200))
        let started = ContinuousClock.now
        let startup = Task { await fixture.store.bootstrap() }
        await waitForRequests(1, in: fixture.scenario)
        guard case .launching = fixture.store.state else { return XCTFail("Do not show retry immediately.") }
        await startup.value

        assertRetryState(fixture)
        XCTAssertGreaterThanOrEqual(started.duration(to: .now), .milliseconds(190))
        XCTAssertEqual(fixture.scenario.requests.count, 1)
    }

    func testRejectedRefreshClearsSession() async {
        for status in [401, 403] {
            let fixture = makeFixture(expired: true, responses: [.json(status, "{}")])
            await fixture.store.bootstrap()

            guard case .signedOut = fixture.store.state else { return XCTFail("Rejected session must require sign-in.") }
            XCTAssertNil(fixture.tokens.tokens)
            XCTAssertNil(fixture.store.currentAccessToken)
            XCTAssertNil(fixture.auth.appleUserID)
        }
    }

    func testRefreshFailureAfterUnexpected401IsNotAutomaticallyReplayed() async {
        let fixture = makeFixture(responses: [.json(401, "{}"), .failure(.timedOut)])
        await fixture.store.bootstrap()

        assertRetryState(fixture)
        XCTAssertEqual(fixture.scenario.requests.map(\.url?.path), ["/me", "/auth/refresh"])
        XCTAssertNotNil(fixture.tokens.tokens)
    }

    func testDeadlineCancelsPendingRefreshAndAllowsAnotherAttempt() async {
        let fixture = makeFixture(expired: true, responses: [.pending, .json(200, sessionJSON)], timeout: .milliseconds(100))
        let started = ContinuousClock.now
        await fixture.store.bootstrap()

        assertRetryState(fixture)
        XCTAssertLessThan(started.duration(to: .now), .seconds(3))
        XCTAssertNotNil(fixture.tokens.tokens)
        XCTAssertEqual(fixture.tokens.clearCount, 0)

        await fixture.store.bootstrap()
        XCTAssertEqual(fixture.store.currentUser?.displayName, "Anna")
        XCTAssertEqual(fixture.scenario.requests.count, 2)
    }

    func testDeadlineCoversProfileAndRefreshTogether() async {
        let fixture = makeFixture(responses: [.json(401, "{}"), .pending], timeout: .milliseconds(100))
        await fixture.store.bootstrap()

        assertRetryState(fixture)
        XCTAssertEqual(fixture.scenario.requests.map(\.url?.path), ["/me", "/auth/refresh"])
        XCTAssertEqual(fixture.tokens.clearCount, 0)
    }

    func testProfileDeadlinePreservesTokensAndManualRetrySucceeds() async {
        let fixture = makeFixture(responses: [.pending, .json(200, userJSON)], timeout: .milliseconds(100))
        await fixture.store.bootstrap()
        assertRetryState(fixture)

        await fixture.store.bootstrap()
        XCTAssertEqual(fixture.store.currentUser?.displayName, "Anna")
        XCTAssertEqual(fixture.tokens.clearCount, 0)
    }

    func testTemporaryProfileFailureRetriesOnlyTheRead() async {
        let fixture = makeFixture(responses: [.json(503, "{}"), .json(200, userJSON)])
        await fixture.store.bootstrap()

        XCTAssertEqual(fixture.store.currentUser?.displayName, "Anna")
        XCTAssertEqual(fixture.scenario.requests.map(\.url?.path), ["/me", "/me"])
        XCTAssertEqual(fixture.tokens.clearCount, 0)
    }

    func testMalformedProfileDoesNotRefreshOrDeleteSession() async {
        let fixture = makeFixture(responses: [.json(200, "not valid JSON")])
        await fixture.store.bootstrap()

        assertRetryState(fixture)
        XCTAssertEqual(fixture.scenario.requests.map(\.url?.path), ["/me"])
        XCTAssertNotNil(fixture.tokens.tokens)
    }

    func testSimultaneousStartupAttemptsUseOneRequest() async {
        let fixture = makeFixture(responses: [.delayed(200, userJSON, .milliseconds(150))])
        let first = Task { await fixture.store.bootstrap() }
        await waitForRequests(1, in: fixture.scenario)
        await fixture.store.bootstrap()
        await first.value

        XCTAssertEqual(fixture.scenario.requests.count, 1)
        XCTAssertEqual(fixture.store.currentUser?.displayName, "Anna")
    }

    func testConcurrentRefreshCallsShareRequestAndPersistTokensBeforeReturning() async throws {
        let fixture = makeFixture(responses: [.json(200, userJSON), .delayed(200, sessionJSON, .milliseconds(150))])
        await fixture.store.bootstrap()
        let store = fixture.store
        let first = Task { @MainActor in try await store.refreshSession() }
        let second = Task { @MainActor in try await store.refreshSession() }
        let tokens = try await [first.value, second.value]

        XCTAssertEqual(tokens, ["fresh-access", "fresh-access"])
        XCTAssertEqual(fixture.tokens.tokens?.accessToken, "fresh-access")
        XCTAssertEqual(fixture.store.currentAccessToken, "fresh-access")
        XCTAssertEqual(fixture.scenario.requests.map(\.url?.path), ["/me", "/auth/refresh"])
    }

    func testTransientRefreshFailureDuringUseKeepsUserSignedIn() async {
        let fixture = makeFixture(responses: [.json(200, userJSON), .json(401, "{}"), .failure(.timedOut)])
        await fixture.store.bootstrap()
        do {
            _ = try await fixture.client.send(APIRequest<User>(method: .get, path: "me"))
            XCTFail("The request should fail while the server is unavailable.")
        } catch {
            XCTAssertTrue(AppError.wrap(error).isConnectivityFailure)
        }

        XCTAssertEqual(fixture.store.currentUser?.displayName, "Anna")
        XCTAssertEqual(fixture.store.currentAccessToken, "saved-access")
        XCTAssertEqual(fixture.tokens.clearCount, 0)
    }

    func testRefreshSuccessFollowedBy401ClearsSession() async {
        let fixture = makeFixture(responses: [.json(401, "{}"), .json(200, sessionJSON), .json(401, "{}")])
        await fixture.store.bootstrap()

        guard case .signedOut = fixture.store.state else { return XCTFail("Repeated rejection must clear the session.") }
        XCTAssertNil(fixture.tokens.tokens)
        XCTAssertEqual(fixture.scenario.requests.map(\.url?.path), ["/me", "/auth/refresh", "/me"])
    }

    func testSignOutCancelsPendingStartupAndDoesNotRestoreOldUser() async {
        let fixture = makeFixture(responses: [.pending, .json(204, "")])
        let startup = Task { await fixture.store.bootstrap() }
        await waitForRequests(1, in: fixture.scenario)
        await fixture.store.signOut()
        await startup.value

        guard case .signedOut = fixture.store.state else { return XCTFail("Sign-out must win over the old startup attempt.") }
        XCTAssertNil(fixture.tokens.tokens)
        XCTAssertNil(fixture.store.currentUser)
    }

    func testNoSavedSessionDoesNotContactServer() async {
        let fixture = makeFixture(responses: [])
        fixture.tokens.tokens = nil
        await fixture.store.bootstrap()

        guard case .signedOut = fixture.store.state else { return XCTFail("No saved session should show welcome.") }
        XCTAssertTrue(fixture.scenario.requests.isEmpty)
    }

    func testAppleSignInWaitsLongerAndDoesNotReplayItsAuthorizationCode() async {
        let fixture = makeFixture(responses: [.failure(.timedOut)])
        await fixture.store.signIn(with: .failure(URLError(.unknown)))

        XCTAssertEqual(fixture.scenario.requests.map(\.url?.path), ["/auth/apple"])
        XCTAssertEqual(fixture.scenario.requests.first?.timeoutInterval, 45)
    }

    private func assertRetryState(_ fixture: Fixture, file: StaticString = #filePath, line: UInt = #line) {
        guard case .restorationFailed = fixture.store.state else {
            return XCTFail("A recoverable failure should offer a retry, not Apple sign-in.", file: file, line: line)
        }
        XCTAssertNil(fixture.store.alertMessage, file: file, line: line)
        XCTAssertEqual(fixture.tokens.clearCount, 0, file: file, line: line)
    }

    private func waitForRequests(_ count: Int, in scenario: SessionScenario) async {
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while scenario.requests.count < count, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(5))
        }
        XCTAssertGreaterThanOrEqual(scenario.requests.count, count)
    }

    private struct Fixture {
        let store: SessionStore
        let client: APIClient
        let tokens: MemoryTokenStore
        let auth: SessionTestAuthService
        let scenario: SessionScenario
    }

    private func makeFixture(expired: Bool = false, responses: [SessionScenario.Response],
                             timeout: Duration = .seconds(3)) -> Fixture {
        let host = "\(UUID().uuidString.lowercased()).example"
        let scenario = SessionScenario(responses)
        SessionURLProtocol.register(scenario, host: host)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SessionURLProtocol.self]
        let client = APIClient(baseURL: URL(string: "https://\(host)")!, urlSession: URLSession(configuration: configuration))
        let tokens = MemoryTokenStore(tokens: SessionTokens(
            accessToken: "saved-access", accessTokenExpiresAt: .now.addingTimeInterval(expired ? -600 : 600),
            refreshToken: "saved-refresh", refreshTokenExpiresAt: .now.addingTimeInterval(86_400)))
        let auth = SessionTestAuthService()
        let store = SessionStore(authService: auth, authRepository: AuthRepository(apiClient: client),
                                 refreshCenter: AppRefreshCenter(), userRepository: UserProfileRepository(apiClient: client),
                                 tokenStore: tokens, startupTimeout: timeout)
        client.sessionProvider = store
        return Fixture(store: store, client: client, tokens: tokens, auth: auth, scenario: scenario)
    }

    private var userJSON: String {
        #"{"id":"7AD7BF4A-7D7C-4DDE-92CA-A6C4B635C922","handle":"anna#1234","displayName":"Anna","relationshipStatus":"Self","friendCount":0,"visiblePlaceReviewCount":0,"visibleDishReviewCount":0,"isMe":true}"#
    }

    private var sessionJSON: String {
        let expiry = ISO8601DateFormatter().string(from: .now.addingTimeInterval(3600))
        return """
        {"accessToken":"fresh-access","accessTokenExpiresAtUtc":"\(expiry)",
         "refreshToken":"fresh-refresh","refreshTokenExpiresAtUtc":"\(expiry)","user":\(userJSON)}
        """
    }
}

private final class MemoryTokenStore: SessionTokenStoring {
    var tokens: SessionTokens?
    private(set) var clearCount = 0
    init(tokens: SessionTokens) { self.tokens = tokens }
    func load() -> SessionTokens? { tokens }
    func save(_ tokens: SessionTokens) throws { self.tokens = tokens }
    func clear() { clearCount += 1; tokens = nil }
}

@MainActor
private final class SessionTestAuthService: AuthServicing {
    var appleUserID: String? = "saved-apple-user"
    func configure(_ request: ASAuthorizationAppleIDRequest) { }
    func credential(from result: Result<ASAuthorization, any Error>) throws -> AppleSignInCredential {
        AppleSignInCredential(userID: "new-apple-user", identityToken: "identity", authorizationCode: "single-use-code",
                              rawNonce: "nonce", displayName: nil, email: nil)
    }
    func credentialState(for userID: String) async throws -> ASAuthorizationAppleIDProvider.CredentialState { .authorized }
    func persistLastAppleUserID(_ userID: String?) { appleUserID = userID }
    func lastAppleUserID() -> String? { appleUserID }
}

private final class SessionScenario: @unchecked Sendable {
    enum Response: Sendable {
        case json(Int, String)
        case delayed(Int, String, Duration)
        case failure(URLError.Code)
        case pending
    }
    private let lock = NSLock()
    private var responses: [Response]
    private var recordedRequests: [URLRequest] = []
    var requests: [URLRequest] { lock.withLock { recordedRequests } }
    init(_ responses: [Response]) { self.responses = responses }
    func next(for request: URLRequest) -> Response {
        lock.withLock {
            recordedRequests.append(request)
            return responses.isEmpty ? .failure(.resourceUnavailable) : responses.removeFirst()
        }
    }
}

private final class SessionURLProtocol: URLProtocol, @unchecked Sendable {
    private static let registryLock = NSLock()
    nonisolated(unsafe) private static var scenarios: [String: SessionScenario] = [:]
    private let taskLock = NSLock()
    private var responseTask: Task<Void, Never>?
    static func register(_ scenario: SessionScenario, host: String) {
        registryLock.withLock { scenarios[host] = scenario }
    }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let scenario = Self.registryLock.withLock { Self.scenarios[request.url?.host ?? ""] }
        guard let scenario else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        switch scenario.next(for: request) {
        case .json(let status, let body):
            respond(status: status, body: body)
        case .failure(let code):
            client?.urlProtocol(self, didFailWithError: URLError(code))
        case .pending:
            break
        case .delayed(let status, let body, let delay):
            let responseTask = Task { @Sendable [self] in
                do {
                    try await Task.sleep(for: delay)
                    respond(status: status, body: body)
                } catch { }
            }
            taskLock.withLock { self.responseTask = responseTask }
        }
    }
    override func stopLoading() { taskLock.withLock { responseTask?.cancel() } }
    private func respond(status: Int, body: String) {
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil,
                                       headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}
