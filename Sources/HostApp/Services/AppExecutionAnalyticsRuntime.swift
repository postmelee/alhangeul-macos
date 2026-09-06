import Foundation
import Network

enum AppExecutionAnalyticsEndpoint {
    static let infoDictionaryKey = "AlhangeulAppExecutionEndpoint"

    static func resolve(bundle: Bundle = .main) -> URL? {
        resolve(value: bundle.object(forInfoDictionaryKey: infoDictionaryKey))
    }

    static func resolve(value: Any?) -> URL? {
        guard let rawValue = value as? String,
              let components = URLComponents(string: rawValue),
              components.scheme?.lowercased() == "https",
              components.host?.isEmpty == false,
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil
        else {
            return nil
        }
        return components.url
    }
}

protocol AppExecutionConnectivityResolving {
    func isConnected() async -> Bool
}

final class AppExecutionOneShotConnectivityResolver: AppExecutionConnectivityResolving {
    private let queue: DispatchQueue
    private let resolutionTimeout: TimeInterval

    init(
        queue: DispatchQueue = DispatchQueue(
            label: "com.postmelee.alhangeul.analytics-connectivity"
        ),
        resolutionTimeout: TimeInterval = 1
    ) {
        self.queue = queue
        self.resolutionTimeout = min(max(resolutionTimeout, 0.1), 5)
    }

    func isConnected() async -> Bool {
        await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            let resolution = AppExecutionPathResolution(
                monitor: monitor,
                continuation: continuation
            )

            monitor.pathUpdateHandler = { path in
                resolution.finish(isConnected: path.status == .satisfied)
            }
            monitor.start(queue: queue)
            queue.asyncAfter(deadline: .now() + resolutionTimeout) {
                resolution.finish(isConnected: false)
            }
        }
    }
}

private final class AppExecutionPathResolution: @unchecked Sendable {
    private let lock = NSLock()
    private var monitor: NWPathMonitor?
    private var continuation: CheckedContinuation<Bool, Never>?

    init(
        monitor: NWPathMonitor,
        continuation: CheckedContinuation<Bool, Never>
    ) {
        self.monitor = monitor
        self.continuation = continuation
    }

    func finish(isConnected: Bool) {
        let completion: (NWPathMonitor, CheckedContinuation<Bool, Never>)? = lock.withLock {
            guard let monitor, let continuation else {
                return nil
            }
            self.monitor = nil
            self.continuation = nil
            return (monitor, continuation)
        }

        guard let (monitor, continuation) = completion else {
            return
        }
        monitor.pathUpdateHandler = nil
        monitor.cancel()
        continuation.resume(returning: isConnected)
    }
}

final class AppExecutionURLSessionTransport: AppExecutionEventTransport {
    static let maximumPayloadBytes = 2 * 1_024
    static let timeout: TimeInterval = 5

    private let endpoint: URL
    private let session: URLSession
    private let redirectDelegate: AppExecutionRedirectRejectingDelegate?
    private let encoder: JSONEncoder

    init(
        endpoint: URL,
        session: URLSession? = nil,
        encoder: JSONEncoder = JSONEncoder()
    ) {
        self.endpoint = endpoint
        self.encoder = encoder
        if let session {
            self.session = session
            redirectDelegate = nil
        } else {
            let redirectDelegate = AppExecutionRedirectRejectingDelegate()
            self.redirectDelegate = redirectDelegate
            self.session = URLSession(
                configuration: Self.makeEphemeralConfiguration(),
                delegate: redirectDelegate,
                delegateQueue: nil
            )
        }
    }

    func send(_ event: AppExecutionEvent) async -> AppExecutionTransportResult {
        guard let payload = try? encoder.encode(event),
              payload.count <= Self.maximumPayloadBytes
        else {
            return .failure(.other)
        }

        var request = URLRequest(
            url: endpoint,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: Self.timeout
        )
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = payload
        request.httpShouldHandleCookies = false

        do {
            let (_, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse else {
                return .failure(.other)
            }
            return .response(statusCode: response.statusCode)
        } catch let error as URLError {
            return error.code == .timedOut
                ? .failure(.timeout)
                : .failure(.network)
        } catch {
            return .failure(.other)
        }
    }

    static func makeEphemeralConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.waitsForConnectivity = false
        configuration.httpAdditionalHeaders = [
            "User-Agent": "Alhangeul",
            "Accept-Language": "en",
        ]
        return configuration
    }
}

final class AppExecutionRedirectRejectingDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

final class AppExecutionAnalyticsCoordinator {
    typealias TransportFactory = (URL) -> AppExecutionEventTransport

    private let stateStore: AppExecutionAnalyticsStateStore
    private let endpoint: URL?
    private let connectivityResolver: AppExecutionConnectivityResolving
    private let transportFactory: TransportFactory
    private let lock = NSLock()
    private var didStart = false
    private var flushTask: Task<Void, Never>?

    init(
        stateStore: AppExecutionAnalyticsStateStore,
        endpoint: URL?,
        connectivityResolver: AppExecutionConnectivityResolving,
        transportFactory: @escaping TransportFactory = {
            AppExecutionURLSessionTransport(endpoint: $0)
        }
    ) {
        self.stateStore = stateStore
        self.endpoint = endpoint
        self.connectivityResolver = connectivityResolver
        self.transportFactory = transportFactory
    }

    var isDeliveryConfigured: Bool {
        endpoint != nil
    }

    func startIfNeeded() {
        lock.withLock {
            guard !didStart else {
                return
            }
            didStart = true
            guard stateStore.isEnabled,
                  !stateStore.load().outbox.isEmpty,
                  let endpoint
            else {
                return
            }

            let connectivityResolver = connectivityResolver
            let processor = AppExecutionOutboxProcessor(
                outbox: AppExecutionOutbox(stateStore: stateStore),
                transport: transportFactory(endpoint)
            )
            flushTask = Task {
                guard await connectivityResolver.isConnected() else {
                    return
                }
                guard !Task.isCancelled, stateStore.isEnabled else {
                    return
                }
                await processor.processCurrentSnapshot()
            }
        }
    }

    func cancel() {
        let task = lock.withLock {
            let task = flushTask
            flushTask = nil
            return task
        }
        task?.cancel()
    }
}

final class AppExecutionAnalyticsRuntime {
    static let shared: AppExecutionAnalyticsRuntime = {
        let stateStore = AppExecutionAnalyticsStateStore()
        return AppExecutionAnalyticsRuntime(
            stateStore: stateStore,
            observer: AppExecutionAnalyticsObserver(
                stateStore: stateStore,
                legacyEvidenceResolver: AppExecutionLegacyEvidenceResolver()
            ),
            coordinator: AppExecutionAnalyticsCoordinator(
                stateStore: stateStore,
                endpoint: AppExecutionAnalyticsEndpoint.resolve(),
                connectivityResolver: AppExecutionOneShotConnectivityResolver()
            )
        )
    }()

    let stateStore: AppExecutionAnalyticsStateStore
    private let observer: AppExecutionAnalyticsObserver
    private let coordinator: AppExecutionAnalyticsCoordinator

    init(
        stateStore: AppExecutionAnalyticsStateStore,
        observer: AppExecutionAnalyticsObserver,
        coordinator: AppExecutionAnalyticsCoordinator
    ) {
        self.stateStore = stateStore
        self.observer = observer
        self.coordinator = coordinator
    }

    func prepareForLaunch(currentVersion: String) {
        // Debug·개발 구성처럼 endpoint가 없는 빌드는 event를 만들지도 않는다.
        // Debug와 Release는 같은 bundle identifier의 UserDefaults를 공유하므로
        // 여기서 enqueue하면 이후 Release 실행이 그 event를 production으로 전송한다.
        guard coordinator.isDeliveryConfigured else {
            return
        }
        observer.observe(currentVersion: currentVersion)
        coordinator.startIfNeeded()
    }

    var isCollectionEnabled: Bool {
        stateStore.isEnabled
    }

    func setCollectionEnabled(_ isEnabled: Bool) {
        stateStore.setEnabled(isEnabled)
        if !isEnabled {
            coordinator.cancel()
        }
    }
}

private extension NSLock {
    func withLock<Result>(_ operation: () -> Result) -> Result {
        lock()
        defer { unlock() }
        return operation()
    }
}
