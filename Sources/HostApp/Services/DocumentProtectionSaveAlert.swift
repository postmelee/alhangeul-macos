import AppKit

@MainActor
enum DocumentProtectionSaveAlert {
    static func confirmSaveTransformation(
        sourceProtection: DocumentSourceProtection,
        conversionIntent: DocumentSaveConversionIntent,
        presentingWindow: NSWindow?
    ) async -> Bool {
        let warningIntent = DocumentSaveWarningIntent.resolve(
            sourceProtection: sourceProtection,
            conversionIntent: conversionIntent
        )
        guard warningIntent.requiresConfirmation else {
            return true
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = messageText(for: warningIntent)
        alert.informativeText = informativeText(
            for: sourceProtection,
            conversionIntent: conversionIntent,
            warningIntent: warningIntent
        )
        alert.addButton(withTitle: confirmationButtonTitle(for: warningIntent))
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

    private static func messageText(for warningIntent: DocumentSaveWarningIntent) -> String {
        switch warningIntent {
        case .conversionCopy:
            return "HWP3 원형을 유지한 채 저장할 수 없습니다."
        case .plainCopy, .plainConversionCopy:
            return "원본의 문서 보호를 유지한 채 저장할 수 없습니다."
        case .none:
            return "문서를 저장합니다."
        }
    }

    private static func confirmationButtonTitle(
        for warningIntent: DocumentSaveWarningIntent
    ) -> String {
        switch warningIntent {
        case .conversionCopy:
            return "변환 복사본 저장"
        case .plainCopy:
            return "평문 복사본 저장"
        case .plainConversionCopy:
            return "평문 변환 복사본 저장"
        case .none:
            return "저장"
        }
    }

    private static func informativeText(
        for sourceProtection: DocumentSourceProtection,
        conversionIntent: DocumentSaveConversionIntent,
        warningIntent: DocumentSaveWarningIntent
    ) -> String {
        let protectionMessage = switch sourceProtection {
        case .plain:
            // 호출부가 requiresPlainCopyWarning으로 거르지만 exhaustive fallback은 유지한다.
            "문서를 다른 이름으로 저장합니다."
        case .passwordProtected:
            "현재 버전은 native 암호 저장을 지원하지 않습니다. 원본은 변경하지 않고, 암호가 제거된 복사본을 원본과 다른 위치에 저장할 수 있습니다."
        case .unsupportedProtection:
            "지원하지 않는 문서 보호 방식이 감지되었습니다. 원본은 변경하지 않고, 현재 편집 내용을 보호되지 않은 복사본으로 저장할 수 있습니다."
        case .invalidOrUnknown:
            "문서 보호 상태를 확인할 수 없습니다. 원본은 변경하지 않고, 현재 편집 내용을 보호되지 않은 복사본으로 저장할 수 있습니다."
        }

        switch warningIntent {
        case .conversionCopy:
            return "현재 편집 내용은 \(convertedFormatName(conversionIntent)) 형식으로 변환됩니다. 원본은 변경하지 않고 새 변환 복사본으로 저장합니다."
        case .plainCopy:
            return protectionMessage
        case .plainConversionCopy:
            return "\(protectionMessage)\n\nHWP3 원형은 보존되지 않으며 \(convertedFormatName(conversionIntent)) 형식으로 변환됩니다. 원본은 변경하지 않고 새 파일에만 저장합니다."
        case .none:
            return "문서를 저장합니다."
        }
    }

    private static func convertedFormatName(
        _ conversionIntent: DocumentSaveConversionIntent
    ) -> String {
        switch conversionIntent {
        case .hwp3ToHwp5:
            return "HWP5"
        case .hwp3ToHwpx:
            return "HWPX"
        case .none:
            return "현재"
        }
    }
}
