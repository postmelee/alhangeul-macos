import XCTest

final class AppExecutionAnalyticsRuntimeTests: XCTestCase {
    private var suiteName: String!
    private var userDefaults: UserDefaults!
    private var stateStore: AppExecutionAnalyticsStateStore!

    override func setUp() {
        super.setUp()
        suiteName = "AppExecutionAnalyticsRuntimeTests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
        stateStore = AppExecutionAnalyticsStateStore(userDefaults: userDefaults)
        AppExecutionURLProtocolStub.handler = nil
    }

    override func tearDown() {
        AppExecutionURLProtocolStub.handler = nil
        userDefaults.removePersistentDomain(forName: suiteName)
        stateStore = nil
        userDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testEndpointAcceptsOnlyCredentialFreeHTTPSURL() {
        XCTAssertEqual(
            AppExecutionAnalyticsEndpoint.resolve(
                value: "https://collector.example/v1/install-events"
            )?.absoluteString,
            "https://collector.example/v1/install-events"
        )

        let invalidValues: [Any?] = [
            nil,
            42,
            "",
            "not-a-url",
            "http://collector.example/v1/install-events",
            "https://user:password@collector.example/v1/install-events",
            "https://collector.example/v1/install-events?token=secret",
            "https://collector.example/v1/install-events#fragment",
        ]
        for value in invalidValues {
            XCTAssertNil(
                AppExecutionAnalyticsEndpoint.resolve(value: value),
                "value=\(String(describing: value))"
            )
        }
    }

    func testEphemeralConfigurationDoesNotPersistRequestState() {
        let configuration = AppExecutionURLSessionTransport.makeEphemeralConfiguration()

        XCTAssertLessThanOrEqual(
            configuration.timeoutIntervalForRequest,
            AppExecutionURLSessionTransport.timeout
        )
        XCTAssertLessThanOrEqual(
            configuration.timeoutIntervalForResource,
            AppExecutionURLSessionTransport.timeout
        )
        XCTAssertEqual(configuration.requestCachePolicy, .reloadIgnoringLocalCacheData)
        XCTAssertNil(configuration.urlCache)
        XCTAssertNil(configuration.httpCookieStorage)
        XCTAssertNil(configuration.urlCredentialStorage)
        XCTAssertFalse(configuration.httpShouldSetCookies)
        XCTAssertFalse(configuration.waitsForConnectivity)
    }

    func testTransportPostsOnlyCollectorPayloadAndReturnsStatusCode() async throws {
        let recorder = AppExecutionRequestRecorder()
        AppExecutionURLProtocolStub.handler = { request in
            var recordedRequest = request
            recordedRequest.httpBody = try appExecutionRequestBody(from: request)
            recorder.record(recordedRequest)
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 202,
                httpVersion: nil,
                headerFields: nil
            )!
            return .response(response, Data())
        }
        let session = makeStubSession()
        let endpoint = URL(string: "https://collector.example/v1/install-events")!
        let transport = AppExecutionURLSessionTransport(
            endpoint: endpoint,
            session: session
        )

        let result = await transport.send(makeEvent(index: 1))

        XCTAssertEqual(result, .response(statusCode: 202))
        let request = try XCTUnwrap(recorder.request)
        XCTAssertEqual(request.url, endpoint)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Content-Type"),
            "application/json"
        )
        XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
        XCTAssertLessThanOrEqual(
            request.timeoutInterval,
            AppExecutionURLSessionTransport.timeout
        )
        XCTAssertFalse(request.httpShouldHandleCookies)

        let payload = try XCTUnwrap(request.httpBody)
        XCTAssertLessThanOrEqual(
            payload.count,
            AppExecutionURLSessionTransport.maximumPayloadBytes
        )
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: payload) as? [String: Any]
        )
        XCTAssertEqual(
            Set(object.keys),
            Set([
                "event_id",
                "event_type",
                "occurred_date",
                "from_version",
                "to_version",
                "update_channel",
            ])
        )
    }

    func testTransportMapsTimeoutWithoutThrowing() async {
        AppExecutionURLProtocolStub.handler = { _ in
            .failure(URLError(.timedOut))
        }
        let transport = AppExecutionURLSessionTransport(
            endpoint: URL(string: "https://collector.example/v1/install-events")!,
            session: makeStubSession()
        )

        let result = await transport.send(makeEvent(index: 1))

        XCTAssertEqual(result, .failure(.timeout))
    }

    func testUnsatisfiedConnectivitySkipsTransport() async {
        seed(entries: [makeEntry(index: 1)])
        let connectivityChecked = expectation(description: "connectivity checked")
        let connectivity = TestAppExecutionConnectivityResolver(
            result: false,
            onCheck: { connectivityChecked.fulfill() }
        )
        let transport = TestAppExecutionTransport(result: .response(statusCode: 202))
        let coordinator = makeCoordinator(
            connectivity: connectivity,
            transport: transport
        )

        coordinator.startIfNeeded()

        await fulfillment(of: [connectivityChecked], timeout: 1)
        await waitForAsyncTurn()
        XCTAssertEqual(connectivity.checkCount, 1)
        XCTAssertEqual(transport.sentEventIDs, [])
        XCTAssertEqual(stateStore.load().outbox.count, 1)
        XCTAssertNil(stateStore.load().outbox.first?.firstAttemptedAt)
    }

    func testCoordinatorStartsOnlyOneFlushPass() async {
        let entry = makeEntry(index: 1)
        seed(entries: [entry])
        let sent = expectation(description: "event sent")
        let connectivity = TestAppExecutionConnectivityResolver(result: true)
        let transport = TestAppExecutionTransport(
            result: .response(statusCode: 202),
            onSend: { _ in sent.fulfill() }
        )
        let coordinator = makeCoordinator(
            connectivity: connectivity,
            transport: transport
        )

        coordinator.startIfNeeded()
        coordinator.startIfNeeded()

        await fulfillment(of: [sent], timeout: 1)
        let didRemoveAcceptedEvent = await waitUntil {
            self.stateStore.load().outbox.isEmpty
        }
        XCTAssertTrue(didRemoveAcceptedEvent)
        XCTAssertEqual(connectivity.checkCount, 1)
        XCTAssertEqual(transport.sentEventIDs, [entry.id])
    }

    func testMissingEndpointSkipsConnectivityAndTransport() async {
        seed(entries: [makeEntry(index: 1)])
        let connectivity = TestAppExecutionConnectivityResolver(result: true)
        let transport = TestAppExecutionTransport(result: .response(statusCode: 202))
        let coordinator = AppExecutionAnalyticsCoordinator(
            stateStore: stateStore,
            endpoint: nil,
            connectivityResolver: connectivity,
            transportFactory: { _ in transport }
        )

        coordinator.startIfNeeded()
        await waitForAsyncTurn()

        XCTAssertEqual(connectivity.checkCount, 0)
        XCTAssertEqual(transport.sentEventIDs, [])
        XCTAssertEqual(stateStore.load().outbox.count, 1)
    }

    func testStartReturnsWhileConnectivityCheckIsSuspended() async {
        seed(entries: [makeEntry(index: 1)])
        let connectivityStarted = expectation(description: "connectivity suspended")
        let connectivity = SuspendingAppExecutionConnectivityResolver(
            onStart: { connectivityStarted.fulfill() }
        )
        let transport = TestAppExecutionTransport(result: .response(statusCode: 202))
        let coordinator = makeCoordinator(
            connectivity: connectivity,
            transport: transport
        )

        coordinator.startIfNeeded()
        let didReturnFromStart = true

        await fulfillment(of: [connectivityStarted], timeout: 1)
        XCTAssertTrue(didReturnFromStart)
        XCTAssertEqual(transport.sentEventIDs, [])
        connectivity.finish(result: false)
    }

    func testOptOutCancelsSuspendedFlushBeforeTransport() async {
        seed(entries: [makeEntry(index: 1)])
        let connectivityStarted = expectation(description: "connectivity suspended")
        let connectivity = SuspendingAppExecutionConnectivityResolver(
            onStart: { connectivityStarted.fulfill() }
        )
        let transport = TestAppExecutionTransport(result: .response(statusCode: 202))
        let coordinator = makeCoordinator(
            connectivity: connectivity,
            transport: transport
        )
        coordinator.startIfNeeded()
        await fulfillment(of: [connectivityStarted], timeout: 1)

        stateStore.setEnabled(false)
        coordinator.cancel()
        connectivity.finish(result: true)
        await waitForAsyncTurn()

        XCTAssertFalse(stateStore.isEnabled)
        XCTAssertTrue(stateStore.load().outbox.isEmpty)
        XCTAssertEqual(transport.sentEventIDs, [])
    }

    func testNewCoordinatorRetriesOnlyRemainingEventOnNextLaunch() async {
        let entry = makeEntry(index: 1)
        seed(entries: [entry])
        let firstSent = expectation(description: "first launch send")
        let firstTransport = TestAppExecutionTransport(
            result: .response(statusCode: 503),
            onSend: { _ in firstSent.fulfill() }
        )
        makeCoordinator(
            connectivity: TestAppExecutionConnectivityResolver(result: true),
            transport: firstTransport
        ).startIfNeeded()

        await fulfillment(of: [firstSent], timeout: 1)
        let didPersistFirstAttempt = await waitUntil {
            self.stateStore.load().outbox.first?.firstAttemptedAt != nil
        }
        XCTAssertTrue(didPersistFirstAttempt)

        let retrySent = expectation(description: "next launch retry")
        let retryTransport = TestAppExecutionTransport(
            result: .response(statusCode: 202),
            onSend: { _ in retrySent.fulfill() }
        )
        makeCoordinator(
            connectivity: TestAppExecutionConnectivityResolver(result: true),
            transport: retryTransport
        ).startIfNeeded()

        await fulfillment(of: [retrySent], timeout: 1)
        let didRemoveRetriedEvent = await waitUntil {
            self.stateStore.load().outbox.isEmpty
        }
        XCTAssertTrue(didRemoveRetriedEvent)
        XCTAssertEqual(firstTransport.sentEventIDs, [entry.id])
        XCTAssertEqual(retryTransport.sentEventIDs, [entry.id])
        XCTAssertEqual(stateStore.load().lastAcceptedVersion, entry.event.toVersion)
    }

    func testOfflineLaunchThenConnectedLaunchSendsOriginalOccurredDate() async {
        let entry = makeEntry(index: 1)
        seed(entries: [entry])
        let offlineChecked = expectation(description: "offline path checked")
        makeCoordinator(
            connectivity: TestAppExecutionConnectivityResolver(
                result: false,
                onCheck: { offlineChecked.fulfill() }
            ),
            transport: TestAppExecutionTransport(result: .response(statusCode: 202))
        ).startIfNeeded()

        await fulfillment(of: [offlineChecked], timeout: 1)
        await waitForAsyncTurn()
        XCTAssertEqual(stateStore.load().outbox, [entry])
        XCTAssertNil(stateStore.load().outbox.first?.firstAttemptedAt)

        let restoredSend = expectation(description: "restored path sent")
        let restoredTransport = TestAppExecutionTransport(
            result: .response(statusCode: 202),
            onSend: { _ in restoredSend.fulfill() }
        )
        makeCoordinator(
            connectivity: TestAppExecutionConnectivityResolver(result: true),
            transport: restoredTransport
        ).startIfNeeded()

        await fulfillment(of: [restoredSend], timeout: 1)
        let didRemoveAcceptedEvent = await waitUntil {
            self.stateStore.load().outbox.isEmpty
        }
        XCTAssertTrue(didRemoveAcceptedEvent)
        XCTAssertEqual(restoredTransport.sentEvents.map(\.occurredDate), ["2026-08-04"])
        XCTAssertEqual(restoredTransport.sentEvents.map(\.id), [entry.id])
    }

    private func makeCoordinator(
        connectivity: AppExecutionConnectivityResolving,
        transport: AppExecutionEventTransport
    ) -> AppExecutionAnalyticsCoordinator {
        AppExecutionAnalyticsCoordinator(
            stateStore: stateStore,
            endpoint: URL(string: "https://collector.example/v1/install-events"),
            connectivityResolver: connectivity,
            transportFactory: { _ in transport }
        )
    }

    private func seed(entries: [AppExecutionOutboxEntry]) {
        XCTAssertTrue(stateStore.update { $0.outbox = entries })
    }

    private func makeEntry(index: Int) -> AppExecutionOutboxEntry {
        let event = makeEvent(index: index)
        return AppExecutionOutboxEntry(
            event: event,
            createdAt: date("2026-08-04T00:00:00Z"),
            firstAttemptedAt: nil
        )
    }

    private func makeEvent(index: Int) -> AppExecutionEvent {
        AppExecutionEvent.make(
            eventID: UUID(
                uuidString: String(
                    format: "00000000-0000-4000-8000-%012llx",
                    UInt64(index)
                )
            )!,
            eventType: .firstLaunch,
            occurredAt: date("2026-08-04T00:00:00Z"),
            fromVersion: nil,
            toVersion: "0.1.9",
            updateChannel: .unknown
        )!
    }

    private func makeStubSession() -> URLSession {
        let configuration = AppExecutionURLSessionTransport.makeEphemeralConfiguration()
        configuration.protocolClasses = [AppExecutionURLProtocolStub.self]
        return URLSession(configuration: configuration)
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }

    private func waitForAsyncTurn() async {
        try? await Task.sleep(nanoseconds: 20_000_000)
    }

    private func waitUntil(
        timeout: TimeInterval = 1,
        condition: @escaping () -> Bool
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return true
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        return condition()
    }
}

private final class TestAppExecutionConnectivityResolver: AppExecutionConnectivityResolving {
    private let lock = NSLock()
    private let result: Bool
    private let onCheck: (() -> Void)?
    private var storedCheckCount = 0

    var checkCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return storedCheckCount
    }

    init(result: Bool, onCheck: (() -> Void)? = nil) {
        self.result = result
        self.onCheck = onCheck
    }

    func isConnected() async -> Bool {
        recordCheck()
        onCheck?()
        return result
    }

    private func recordCheck() {
        lock.lock()
        storedCheckCount += 1
        lock.unlock()
    }
}

private final class SuspendingAppExecutionConnectivityResolver: AppExecutionConnectivityResolving {
    private let lock = NSLock()
    private let onStart: () -> Void
    private var continuation: CheckedContinuation<Bool, Never>?

    init(onStart: @escaping () -> Void) {
        self.onStart = onStart
    }

    func isConnected() async -> Bool {
        await withCheckedContinuation { continuation in
            lock.lock()
            self.continuation = continuation
            lock.unlock()
            onStart()
        }
    }

    func finish(result: Bool) {
        lock.lock()
        let continuation = continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(returning: result)
    }
}

private final class TestAppExecutionTransport: AppExecutionEventTransport {
    private let lock = NSLock()
    private let result: AppExecutionTransportResult
    private let onSend: ((AppExecutionEvent) -> Void)?
    private var storedEvents: [AppExecutionEvent] = []

    var sentEventIDs: [UUID] {
        lock.lock()
        defer { lock.unlock() }
        return storedEvents.map(\.id)
    }

    var sentEvents: [AppExecutionEvent] {
        lock.lock()
        defer { lock.unlock() }
        return storedEvents
    }

    init(
        result: AppExecutionTransportResult,
        onSend: ((AppExecutionEvent) -> Void)? = nil
    ) {
        self.result = result
        self.onSend = onSend
    }

    func send(_ event: AppExecutionEvent) async -> AppExecutionTransportResult {
        record(event)
        onSend?(event)
        return result
    }

    private func record(_ event: AppExecutionEvent) {
        lock.lock()
        storedEvents.append(event)
        lock.unlock()
    }
}

private final class AppExecutionRequestRecorder {
    private let lock = NSLock()
    private var storedRequest: URLRequest?

    var request: URLRequest? {
        lock.lock()
        defer { lock.unlock() }
        return storedRequest
    }

    func record(_ request: URLRequest) {
        lock.lock()
        storedRequest = request
        lock.unlock()
    }
}

private func appExecutionRequestBody(from request: URLRequest) throws -> Data? {
    if let body = request.httpBody {
        return body
    }
    guard let stream = request.httpBodyStream else {
        return nil
    }

    stream.open()
    defer { stream.close() }
    var body = Data()
    var buffer = [UInt8](repeating: 0, count: 1_024)
    while stream.hasBytesAvailable {
        let count = stream.read(&buffer, maxLength: buffer.count)
        if count < 0 {
            throw stream.streamError ?? URLError(.cannotDecodeContentData)
        }
        if count == 0 {
            break
        }
        body.append(buffer, count: count)
    }
    return body
}

private enum AppExecutionURLProtocolStubResult {
    case response(HTTPURLResponse, Data)
    case failure(Error)
}

private final class AppExecutionURLProtocolStub: URLProtocol {
    static var handler: ((URLRequest) throws -> AppExecutionURLProtocolStubResult)?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            guard let handler = Self.handler else {
                throw URLError(.unknown)
            }
            switch try handler(request) {
            case let .response(response, data):
                client?.urlProtocol(
                    self,
                    didReceive: response,
                    cacheStoragePolicy: .notAllowed
                )
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            case let .failure(error):
                client?.urlProtocol(self, didFailWithError: error)
            }
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
