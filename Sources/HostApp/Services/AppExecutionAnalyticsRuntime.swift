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
    private let encoder: JSONEncoder

    init(
        endpoint: URL,
        session: URLSession? = nil,
        encoder: JSONEncoder = JSONEncoder()
    ) {
        self.endpoint = endpoint
        self.session = session ?? URLSession(
            configuration: Self.makeEphemeralConfiguration()
        )
        self.encoder = encoder
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
        return configuration
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

    func startIfNeeded() {
        let shouldStart = lock.withLock {
            guard !didStart else {
                return false
            }
            didStart = true
            return true
        }
        guard shouldStart,
              stateStore.isEnabled,
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
        Task {
            guard await connectivityResolver.isConnected() else {
                return
            }
            await processor.processCurrentSnapshot()
        }
    }
}

final class AppExecutionAnalyticsRuntime {
    static let shared: AppExecutionAnalyticsRuntime = {
        let stateStore = AppExecutionAnalyticsStateStore()
        return AppExecutionAnalyticsRuntime(
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

    private let observer: AppExecutionAnalyticsObserver
    private let coordinator: AppExecutionAnalyticsCoordinator

    init(
        observer: AppExecutionAnalyticsObserver,
        coordinator: AppExecutionAnalyticsCoordinator
    ) {
        self.observer = observer
        self.coordinator = coordinator
    }

    func prepareForLaunch(currentVersion: String) {
        observer.observe(currentVersion: currentVersion)
        coordinator.startIfNeeded()
    }
}

private extension NSLock {
    func withLock<Result>(_ operation: () -> Result) -> Result {
        lock()
        defer { unlock() }
        return operation()
    }
}
