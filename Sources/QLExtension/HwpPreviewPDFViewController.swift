import AppKit
import Foundation
import OSLog
import PDFKit
import QuickLookUI

final class HwpPreviewPDFViewController: NSViewController, QLPreviewingController {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.postmelee.alhangeul.QLExtension",
        category: "PDFViewProbe"
    )

    private let pdfView = PDFView()
    private let thumbnailView = PDFThumbnailView()
    private let statusLabel = NSTextField(labelWithString: "")

    private var generation = 0
    private var activeWorkItem: DispatchWorkItem?
    private var activeRecorder: HwpPDFViewLazyProbeRecorder?

    deinit {
        activeWorkItem?.cancel()
    }

    override func loadView() {
        let rootView = NSView()
        rootView.wantsLayer = true
        rootView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = true
        pdfView.backgroundColor = .windowBackgroundColor
        pdfView.translatesAutoresizingMaskIntoConstraints = false

        thumbnailView.pdfView = pdfView
        thumbnailView.thumbnailSize = NSSize(width: 96, height: 132)
        thumbnailView.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.alignment = .center
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.maximumNumberOfLines = 0
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        rootView.addSubview(pdfView)
        rootView.addSubview(thumbnailView)
        rootView.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            pdfView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            pdfView.topAnchor.constraint(equalTo: rootView.topAnchor),
            pdfView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),

            thumbnailView.leadingAnchor.constraint(equalTo: pdfView.trailingAnchor, constant: 12),
            thumbnailView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -12),
            thumbnailView.topAnchor.constraint(equalTo: rootView.topAnchor, constant: 12),
            thumbnailView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor, constant: -12),
            thumbnailView.widthAnchor.constraint(equalToConstant: 132),

            statusLabel.centerXAnchor.constraint(equalTo: pdfView.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: pdfView.centerYAnchor),
            statusLabel.widthAnchor.constraint(lessThanOrEqualTo: pdfView.widthAnchor, multiplier: 0.8)
        ])

        view = rootView
        showStatus("미리보기 준비 중...")
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        activeWorkItem?.cancel()
    }

    func preparePreviewOfFile(
        at url: URL,
        completionHandler handler: @escaping (Error?) -> Void
    ) {
        generation += 1
        let currentGeneration = generation
        activeWorkItem?.cancel()
        showStatus("미리보기 준비 중...")
        logger.notice("PDFView probe prepare file=\(url.lastPathComponent, privacy: .public) generation=\(currentGeneration, privacy: .public)")

        handler(nil)

        let workItem = DispatchWorkItem { [weak self] in
            do {
                let metadata = try HwpPDFViewLazyProbe.metadata(for: url)
                DispatchQueue.main.async { [weak self] in
                    self?.installProbeDocument(
                        metadata: metadata,
                        generation: currentGeneration
                    )
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.showError(error, filename: url.lastPathComponent, generation: currentGeneration)
                }
            }
        }
        activeWorkItem = workItem
        DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
    }

    private func installProbeDocument(
        metadata: HwpPDFViewLazyProbeMetadata,
        generation currentGeneration: Int
    ) {
        guard currentGeneration == generation else {
            logger.debug("PDFView probe stale metadata discarded generation=\(currentGeneration, privacy: .public)")
            return
        }

        let recorder = HwpPDFViewLazyProbeRecorder(
            logger: logger,
            filename: metadata.filename
        )
        let document = HwpPDFViewLazyProbe.makeDocument(
            metadata: metadata,
            generation: currentGeneration,
            recorder: recorder
        )
        activeRecorder = recorder
        pdfView.document = document
        pdfView.autoScales = true
        statusLabel.isHidden = true
        logger.notice("PDFView probe installed file=\(metadata.filename, privacy: .public) pages=\(metadata.pageCount, privacy: .public) generation=\(currentGeneration, privacy: .public)")
    }

    private func showError(
        _ error: Error,
        filename: String,
        generation currentGeneration: Int
    ) {
        guard currentGeneration == generation else {
            logger.debug("PDFView probe stale error discarded generation=\(currentGeneration, privacy: .public)")
            return
        }

        let message: String
        if let reason = HwpDocumentFallbackClassifier.reason(for: error) {
            message = HwpDocumentFallbackClassifier.quickLookMessage(for: reason)
        } else {
            message = "이 문서의 미리보기를 만들 수 없습니다. 알한글 앱에서 열어 확인해 주세요."
        }
        logger.warning("PDFView probe fallback file=\(filename, privacy: .public) error=\(Self.errorDescription(error), privacy: .public)")
        pdfView.document = nil
        showStatus(message)
    }

    private func showStatus(_ message: String) {
        statusLabel.stringValue = message
        statusLabel.isHidden = false
    }

    private static func errorDescription(_ error: Error) -> String {
        let nsError = error as NSError
        return "\(type(of: error))(domain=\(nsError.domain), code=\(nsError.code))"
    }
}
