import Darwin
import Foundation
import OSLog

/// 첫 실행에서 기존 문서도 importer에 전달하도록 요청한다.
/// 요청 접수는 색인 완료를 의미하지 않는다. 검색 결과는 Spotlight가 비동기로 갱신한다.
enum SpotlightReindexService {
    private static let queue = DispatchQueue(label: "com.postmelee.alhangeul.spotlight-reindex", qos: .utility)
    private static let logger = Logger(subsystem: "com.postmelee.alhangeul", category: "SpotlightReindex")
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

    static func start(appBundleURL: URL, buildIdentifier: String) {
        queue.async {
            let importerURL = appBundleURL.appendingPathComponent("Contents/Library/Spotlight/Alhangeul.mdimporter", isDirectory: true)
            guard let values = try? importerURL.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey]),
                  values.isDirectory == true, let modificationDate = values.contentModificationDate else {
                logger.error("Bundled Spotlight importer unavailable; request deferred until next launch")
                return
            }
            let installation = Installation(importerURL: importerURL, buildIdentifier: buildIdentifier, modificationDate: modificationDate)
            let result = requestIfNeeded(
                installation: installation, userDefaults: .standard,
                waitForDiscovery: waitForDiscovery, submit: submit
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

    private static func waitForDiscovery(importerURL: URL) -> Bool {
        // 동일 ID의 설치 이력이 있는 환경에서 발견까지 4분 이상 지연됨을 관찰했다.
        let deadline = ProcessInfo.processInfo.systemUptime + 600
        repeat {
            guard let output = run(arguments: ["-L"]) else { return false }
            if catalog(output, contains: importerURL) { return true }
            let remaining = deadline - ProcessInfo.processInfo.systemUptime
            if remaining <= 0 { return false }
            Thread.sleep(forTimeInterval: min(5, remaining))
        } while true
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

    private static func run(arguments: [String]) -> String? {
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("alhangeul-spotlight-\(UUID().uuidString).log")
        guard FileManager.default.createFile(atPath: outputURL.path, contents: nil) else { return nil }
        defer { try? FileManager.default.removeItem(at: outputURL) }
        guard let output = try? FileHandle(forUpdating: outputURL) else { return nil }
        defer {
            try? output.close()
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdimport")
        process.arguments = arguments
        // pipe를 채운 프로세스가 종료 대기와 교착하지 않도록 컨테이너 임시 파일을 사용한다.
        process.standardOutput = output
        process.standardError = output
        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in finished.signal() }
        do {
            try process.run()
        } catch {
            return nil
        }
        guard finished.wait(timeout: .now() + 30) == .success else {
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
