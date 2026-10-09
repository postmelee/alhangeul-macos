import AppKit

enum RhwpStudioOutputFontFallbackAlert {
    @MainActor
    static func confirm(_ failures: [RhwpStudioOutputFontFailure], window: NSWindow?) async -> Bool {
        let families = Array(Set(failures.map(\.family))).sorted()
        guard !families.isEmpty else { return false }
        let names = families.prefix(8).joined(separator:"\n")
        let remainder = families.count > 8 ? "\n외 \(families.count - 8)개" : ""
        let alert = NSAlert()
        alert.messageText = "일부 글꼴을 PDF에 포함할 수 없습니다."
        alert.informativeText = "\(names)\(remainder)\n\n대체 글꼴로 출력하면 글자의 모양이나 간격이 달라질 수 있습니다. 원본 문서의 글꼴은 변경하지 않습니다."
        alert.alertStyle = .warning
        alert.addButton(withTitle:"취소")
        alert.addButton(withTitle:"대체 글꼴로 출력")
        if let window {
            return await withCheckedContinuation { done in
                alert.beginSheetModal(for:window) { done.resume(returning:$0 == .alertSecondButtonReturn) }
            }
        }
        return alert.runModal() == .alertSecondButtonReturn
    }
}
