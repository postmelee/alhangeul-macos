import Foundation

// 동일 그룹 entitlement로 서명한 격리 앱에서 실행한다. 제품 manifest는 생성하지 않는다.
do {
    let root = try FontLibraryLocation().resolve()
    let probe = root.deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent(".font-library-probe-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: probe, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: probe) }
    let file = probe.appendingPathComponent("roundtrip")
    let bytes = Data(UUID().uuidString.utf8)
    try bytes.write(to: file, options: .atomic)
    guard try Data(contentsOf: file) == bytes else { throw CocoaError(.fileReadCorruptFile) }
    try FileManager.default.removeItem(at: probe)
    guard !FileManager.default.fileExists(atPath: probe.path) else { throw CocoaError(.fileWriteUnknown) }
    print("PASS: signed sandbox App Group read/write; temporary probe removed")
} catch {
    // 사용자의 절대 경로나 서명 계정 정보는 출력하지 않는다.
    if let reason = error as? FontLibraryLocationError {
        print("FAIL: App Group location: \(reason)")
    } else {
        print("FAIL: App Group read/write (\((error as NSError).domain):\((error as NSError).code))")
    }
    exit(1)
}
