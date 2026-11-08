import AppKit
import SwiftUI

struct ErrorReportDisclosure: View {
    let report: String
    var copyReport: (String) -> Bool = { writeReport($0, to: .general) }

    static func writeReport(_ report: String, to pasteboard: NSPasteboard) -> Bool {
        pasteboard.clearContents()
        return pasteboard.setString(report, forType: .string)
    }
    @State private var isExpanded = false
    @State private var didCopy = false

    var body: some View {
        DisclosureGroup("오류 세부정보", isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                ScrollView {
                    Text(report)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("error-report-text")
                }
                .frame(height: 180)
                HStack {
                    Text("버그 제보에 그대로 붙여 넣을 수 있습니다.")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button(didCopy ? "복사됨" : "복사") { didCopy = copyReport(report) }
                        .accessibilityIdentifier("copy-error-report")
                }
            }
            .padding(12)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: report) { _ in didCopy = false }
    }
}
