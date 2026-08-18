import AppKit

@MainActor
enum DocumentProtectionSaveAlert {
    static func confirmPlainCopy(
        sourceProtection: DocumentSourceProtection,
        isHWP3Source: Bool,
        outputFormat: DocumentSaveFormat,
        presentingWindow: NSWindow?
    ) async -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "원본의 문서 보호를 유지한 채 저장할 수 없습니다."
        alert.informativeText = informativeText(
            for: sourceProtection,
            isHWP3Source: isHWP3Source,
            outputFormat: outputFormat
        )
        alert.addButton(withTitle: "평문 복사본 저장")
        alert.addButton(withTitle: "취소")

        guard let presentingWindow else {
            return alert.runModal() == .alertFirstButtonReturn
        }

        return await withCheckedContinuation { continuation in
            alert.beginSheetModal(for: presentingWindow) { response in
                continuation.resume(returning: response == .alertFirstButtonReturn)
            }
        }
    }

    private static func informativeText(
        for sourceProtection: DocumentSourceProtection,
        isHWP3Source: Bool,
        outputFormat: DocumentSaveFormat
    ) -> String {
        let protectionMessage = switch sourceProtection {
        case .plain:
            "문서를 다른 이름으로 저장합니다."
        case .passwordProtected:
            "현재 버전은 native 암호 저장을 지원하지 않습니다. 원본은 변경하지 않고, 암호가 제거된 복사본을 원본과 다른 위치에 저장할 수 있습니다."
        case .unsupportedProtection:
            "지원하지 않는 문서 보호 방식이 감지되었습니다. 원본은 변경하지 않고, 현재 편집 내용을 보호되지 않은 복사본으로 저장할 수 있습니다."
        case .invalidOrUnknown:
            "문서 보호 상태를 확인할 수 없습니다. 원본은 변경하지 않고, 현재 편집 내용을 보호되지 않은 복사본으로 저장할 수 있습니다."
        }

        guard isHWP3Source else {
            return protectionMessage
        }
        return "\(protectionMessage)\n\nHWP3 원형은 보존되지 않으며 \(outputFormat.rawValue.uppercased()) 형식으로 변환됩니다."
    }
}
