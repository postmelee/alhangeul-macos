import Darwin
import Foundation
import OSLog

/// 첫 실행에서 기존 문서도 importer에 전달하도록 요청한다.
/// 요청 접수는 색인 완료를 의미하지 않는다. 검색 결과는 Spotlight가 비동기로 갱신한다.
enum SpotlightReindexService {
    private static let queue = DispatchQueue(label: "com.postmelee.alhangeul.spotlight-reindex", qos: .utility)
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.postmelee.alhangeul", category: "SpotlightReindex")
    static let requestedInstallationKey = "alhangeul.spotlight.reimport.requestedInstallation"

    struct Installation: Equatable {
        let importerURL: URL
        let buildIdentifier: String
        let modificationDate: Date

        var receipt: [String: String] {
            [
                "importerPath": importerURL.standardizedFileURL.path,
                "buildIdentifier": buildIdentifier,
                "modificationDate": String(modificationDate.timeIntervalSinceReferenceDate)
            ]
        }
    }

    enum Result: Equatable {
        case alreadyRequested
        case requested
        case failed
    }

    static func importerURL(in appBundleURL: URL) -> URL {
        appBundleURL.appendingPathComponent("Contents/Library/Spotlight/Alhangeul.mdimporter", isDirectory: true)
    }

    struct Operations {
        var schedule: (@escaping () -> Void) -> Void = { queue.async(execute: $0) }
        var waitForDiscovery: (URL) -> Bool = discoverImporter
        var submit: (URL) -> Bool = SpotlightReindexService.submit
    }

    static func start(
        appBundleURL: URL,
        buildIdentifier: String,
        userDefaults: UserDefaults,
        operations: Operations = Operations()
    ) {
        operations.schedule {
            let importerURL = importerURL(in: appBundleURL)
            guard let values = try? importerURL.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey]),
                  values.isDirectory == true, let modificationDate = values.contentModificationDate else {
                logger.error("Bundled Spotlight importer unavailable; request deferred until next launch")
                return
            }
            let installation = Installation(importerURL: importerURL, buildIdentifier: buildIdentifier, modificationDate: modificationDate)
            let result = requestIfNeeded(
                installation: installation, userDefaults: userDefaults,
                waitForDiscovery: operations.waitForDiscovery, submit: operations.submit
            )
            switch result {
            case .alreadyRequested:
                logger.debug("Spotlight reimport already requested build=\(buildIdentifier, privacy: .public)")
            case .requested:
                logger.notice("Spotlight reimport request accepted build=\(buildIdentifier, privacy: .public); indexing is asynchronous")
            case .failed:
                logger.error("Spotlight reimport request failed build=\(buildIdentifier, privacy: .public); retry on next launch")
            }
        }
    }

    /// 직렬 worker에서 호출한다. 실패한 요청은 완료 기록을 남기지 않는다.
    @discardableResult
    static func requestIfNeeded(
        installation: Installation,
        userDefaults: UserDefaults,
        waitForDiscovery: (URL) -> Bool,
        submit: (URL) -> Bool
    ) -> Result {
        guard userDefaults.dictionary(forKey: requestedInstallationKey) as? [String: String] != installation.receipt else {
            return .alreadyRequested
        }
        // 발견 전에 -r이 종료 코드 0을 반환해도 기존 문서가 색인되지 않을 수 있다.
        guard waitForDiscovery(installation.importerURL), submit(installation.importerURL) else { return .failed }
        userDefaults.set(installation.receipt, forKey: requestedInstallationKey)
        return .requested
    }

    private static func discoverImporter(importerURL: URL) -> Bool {
        pollForDiscovery(importerURL: importerURL)
    }

    static func pollForDiscovery(
        importerURL: URL,
        timeout: TimeInterval = 600,
        now: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
        sleep: (TimeInterval) -> Void = Thread.sleep(forTimeInterval:),
        readCatalog: (TimeInterval) -> String? = { run(arguments: ["-L"], timeout: $0) }
    ) -> Bool {
        // 동일 ID의 설치 이력이 있는 환경에서 발견까지 4분 이상 지연됨을 관찰했다.
        let deadline = now() + timeout
        while now() < deadline {
            let commandTimeout = min(30, deadline - now())
            guard commandTimeout > 0 else { return false }
            // 일시적인 조회 실패는 남은 대기 시간을 폐기하지 않는다.
            if let output = readCatalog(commandTimeout), now() < deadline,
               catalog(output, contains: importerURL) { return true }
            let remaining = deadline - now()
            if remaining <= 0 { return false }
            sleep(min(5, remaining))
        }
        return false
    }

    static func catalog(_ output: String, contains importerURL: URL) -> Bool {
        // mdimport -L의 NSArray(OpenStep plist)에서 정확한 경로를 비교한다.
        // 단순 substring은 공백/한글 경로의 escape 또는 비슷한 설치 경로를 오판할 수 있다.
        guard let header = output.range(of: #"Paths: id\([^)]*\)\s*"#, options: .regularExpression),
              let data = String(output[header.upperBound...]).data(using: .utf8),
              let paths = (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String] else {
            return false
        }
        return paths.contains { URL(fileURLWithPath: $0).standardizedFileURL.path == importerURL.standardizedFileURL.path }
    }

    private static func submit(importerURL: URL) -> Bool {
        // importer가 지원하는 형식의 재색인 요청만 한다. 파일 열거/수정이나 볼륨 초기화는 하지 않는다.
        run(arguments: ["-r", importerURL.path]) != nil
    }

    static func run(
        executableURL: URL = URL(fileURLWithPath: "/usr/bin/mdimport"),
        arguments: [String],
        timeout: TimeInterval = 30
    ) -> String? {
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("alhangeul-spotlight-\(UUID().uuidString).log")
        guard FileManager.default.createFile(atPath: outputURL.path, contents: nil) else { return nil }
        defer { try? FileManager.default.removeItem(at: outputURL) }
        guard let output = try? FileHandle(forUpdating: outputURL) else { return nil }
        defer {
            try? output.close()
        }
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        // pipe를 채운 프로세스가 종료 대기와 교착하지 않도록 컨테이너 임시 파일을 사용한다.
        process.standardOutput = output
        // 진단 문장이 catalog 뒤에 섞여 OpenStep 파싱을 깨뜨리지 않게 한다.
        // stderr를 pipe로 보관하지 않아 출력량에 따른 교착도 피한다.
        process.standardError = FileHandle.nullDevice
        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in finished.signal() }
        do {
            try process.run()
        } catch {
            return nil
        }
        guard finished.wait(timeout: .now() + timeout) == .success else {
            process.terminate()
            if finished.wait(timeout: .now() + 2) == .timedOut, process.isRunning {
                kill(process.processIdentifier, SIGKILL)
            }
            return nil
        }
        guard process.terminationReason == .exit, process.terminationStatus == 0 else { return nil }
        do {
            try output.seek(toOffset: 0)
            let data = try output.read(upToCount: 1_048_577) ?? Data()
            guard data.count <= 1_048_576 else { return nil }
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
}
