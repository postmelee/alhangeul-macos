import Foundation

// Host 권한의 읽기 전용 탐색 진단. signed 제품 UI/NSOpenPanel 검증을 대신하지 않는다.
@main
struct MacFontDiscoveryProbe {
    static func main() async throws {
        let discovery = MacFontDiscovery()
        let applications = await discovery.discover(try .defaultApplications())
        let installed = await discovery.discover(try .defaultInstalled())
        let summary: [String: Any] = [
            "execution": "host-read-only-not-product-sandbox",
            "applications": applications.sources.map { source in
                ["name": source.name, "version": source.version ?? "unknown",
                 "kind": source.kind.rawValue,
                 "candidates": applications.candidates.filter { $0.source.id == source.id }.count] as [String: Any]
            },
            "applicationCandidateCount": applications.candidates.count,
            "installedCandidateCount": installed.candidates.count,
            "applicationNotices": applications.notices.map { String(describing: $0.reason) },
            "installedNotices": installed.notices.map { String(describing: $0.reason) },
            "cancelled": applications.cancelled || installed.cancelled
        ]
        let data = try JSONSerialization.data(withJSONObject: summary, options: [.prettyPrinted, .sortedKeys])
        print(String(decoding: data, as: UTF8.self))
    }
}
