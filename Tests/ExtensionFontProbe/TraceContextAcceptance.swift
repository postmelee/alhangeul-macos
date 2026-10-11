import Foundation

#if ALHANGEUL_FONT_EXTENSION_PROBE
private final class TraceContextMeter: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String] = []
    func record(_ kind: String, _ id: String?) {
        lock.lock(); defer { lock.unlock() }
        values.append(kind + ":" + (id ?? "nil"))
    }
    func result() -> [String] { lock.lock(); defer { lock.unlock() }; return values }
}
private enum TraceContextFailure: Error { case controlled }
func verifySynchronousTraceContext() async throws {
    let meter = TraceContextMeter()
    let report: @Sendable (String, UInt64, UInt64, Bool, String?) -> Void = { kind, _, _, _, id in meter.record(kind, id) }
    try await ExtensionFontPerformanceTrace.request.withValue("async-owner") {
        try await ExtensionFontPerformanceTrace.details.withValue(report) { () async throws -> Void in
            ExtensionFontPerformanceTrace.withSynchronousContext(request: "A", details: report) {
                ExtensionFontPerformanceTrace.interval("first", start: 0, success: true)
                ExtensionFontPerformanceTrace.withSynchronousContext(request: "B", details: report) {
                    ExtensionFontPerformanceTrace.interval("nested", start: 0, success: true)
                }
                do {
                    try ExtensionFontPerformanceTrace.withSynchronousContext(request: "C", details: report) { () throws -> Void in
                        throw TraceContextFailure.controlled
                    }
                } catch {}
                ExtensionFontPerformanceTrace.interval("restored", start: 0, success: true)
                ExtensionFontPerformanceTrace.withSynchronousContext(request: nil, details: nil) {
                    ExtensionFontPerformanceTrace.interval("suppressed", start: 0, success: true)
                }
            }
            ExtensionFontPerformanceTrace.interval("outside", start: 0, success: true)
        }
    }
    verify(meter.result() == ["first:A", "nested:B", "restored:A", "outside:async-owner"],
           "동기 진단의 요청/observer override·중첩/오류 복원·nil scope·누출 없음")
}
#endif
