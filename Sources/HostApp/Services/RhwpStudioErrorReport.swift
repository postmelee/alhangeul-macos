import Foundation

/// 화면과 클립보드에 같은 제보용 텍스트를 사용한다. 문서 bytes는 입력받지 않는다.
enum RhwpStudioErrorReport {
    struct Environment {
        let appVersion: String
        let appBuild: String
        let osVersion: String
        let architecture: String
        let core: RhwpProvenance?

        static func current(bundle: Bundle = .main) -> Self {
            #if arch(arm64)
            let architecture = "arm64"
            #else
            let architecture = "x86_64"
            #endif
            return .init(appVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
                appBuild: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
                osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                architecture: architecture, core: RhwpProvenanceLoader.load(bundle: bundle))
        }
    }

    static func make(errorID: UUID, occurredAt: Date, category: String, detail: String,
                     additionalDetail: String?, session: RhwpStudioEditorSnapshot?, loadID: Int,
                     reloadToken: Int, environment: Environment, privateValues: [String]) -> String {
        var lines = ["알한글 오류 보고서", "reportVersion=1", "errorID=\(errorID.uuidString)",
            "occurredAt=\(ISO8601DateFormatter().string(from: occurredAt))",
            "appVersion=\(environment.appVersion)", "appBuild=\(environment.appBuild)",
            "os=\(environment.osVersion)", "architecture=\(environment.architecture)",
            "rhwpRelease=\(environment.core?.releaseTag ?? "unknown")",
            "rhwpCommit=\(environment.core?.resolvedCommit ?? "unknown")",
            "category=\(category)", "loadID=\(loadID)", "reloadToken=\(reloadToken)"]
        if let session {
            lines += ["sessionLoadID=\(session.loadID)", "documentEpoch=\(session.documentEpoch)",
                "sequence=\(session.sequence)", "changeSeq=\(session.changeSeq)",
                "dirty=\(session.dirty)", "ready=\(session.ready)",
                "pageCount=\(session.pageCount)", "format=\(session.format)"]
        }
        lines += ["", "[오류 상세]", sanitize(detail, privateValues: privateValues)]
        if let additionalDetail {
            lines += ["", "[저장본 복사 오류]", sanitize(additionalDetail, privateValues: privateValues)]
        }
        return lines.joined(separator: "\n")
    }

    static func sanitize(_ detail: String, privateValues: [String]) -> String {
        var value = String(decoding: detail.utf8.prefix(16 * 1024), as: UTF8.self)
        if detail.utf8.count > 16 * 1024 { value += "\n[이하 생략]" }
        let privateKeys: Set<String> = ["filename", "payloadFilename", "resolvedFilePath", "resourceDirectoryPath"]
        value = value.components(separatedBy: "\n").map { line in
            guard let equal = line.firstIndex(of: "=") else { return line }
            let key = String(line[..<equal])
            return privateKeys.contains(key) ? "\(key)=[생략]" : line
        }.joined(separator: "\n")
        // URL의 query/fragment에는 문서 이름이나 임시 세션 값이 들어갈 수 있다.
        let urls = try! NSRegularExpression(pattern: #"(?:[A-Za-z][A-Za-z0-9+.-]*):\/\/[^\s<>"']+"#)
        for match in urls.matches(in: value, range: NSRange(value.startIndex..., in: value)).reversed() {
            guard let range = Range(match.range, in: value), var url = URLComponents(string: String(value[range])) else { continue }
            if url.scheme == "file" { value.replaceSubrange(range, with: "[경로 생략]"); continue }
            url.query = nil; url.fragment = nil; url.user = nil; url.password = nil
            value.replaceSubrange(range, with: url.string ?? "[URL 생략]")
        }
        let paths = try! NSRegularExpression(pattern: #"/(?:Users|Volumes|private|var|tmp|Applications|Library|System|opt)/[^\r\n"'<>]+"#)
        value = paths.stringByReplacingMatches(in: value, range: NSRange(value.startIndex..., in: value), withTemplate: "[경로 생략]")
        for secret in privateValues.filter({ !$0.isEmpty }).sorted(by: { $0.count > $1.count }) {
            value = value.replacingOccurrences(of: secret, with: "[문서 정보 생략]")
        }
        return value
    }
}
