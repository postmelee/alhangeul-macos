import Foundation
import XCTest

final class RhwpStudioPDFExportStateTests: XCTestCase {
    func testDocumentChangeInvalidatesPendingRequestButKeepsActiveExport() {
        let request = RhwpStudioPDFExportRequest(id: 1, loadID: 10)
        let destinationURL = URL(fileURLWithPath: "/tmp/export.pdf")
        var state = RhwpStudioPDFExportState.idle

        XCTAssertTrue(state.beginChoosingDestination(for: request))
        state.invalidatePendingRequestForDocumentChange()
        XCTAssertEqual(state, .idle)

        XCTAssertTrue(state.beginChoosingDestination(for: request))
        XCTAssertTrue(
            state.beginCollectingPages(
                for: request,
                destinationURL: destinationURL,
                currentLoadID: request.loadID
            )
        )
        state.invalidatePendingRequestForDocumentChange()
        XCTAssertEqual(state, .idle)

        XCTAssertTrue(state.beginChoosingDestination(for: request))
        XCTAssertTrue(
            state.beginCollectingPages(
                for: request,
                destinationURL: destinationURL,
                currentLoadID: request.loadID
            )
        )
        XCTAssertEqual(state.beginExporting(requestID: request.id), destinationURL)
        state.invalidatePendingRequestForDocumentChange()
        XCTAssertEqual(state, .exporting(requestID: request.id))
    }

    func testStaleDestinationSelectionCannotReplaceNewRequest() {
        let staleRequest = RhwpStudioPDFExportRequest(id: 1, loadID: 10)
        let currentRequest = RhwpStudioPDFExportRequest(id: 2, loadID: 11)
        let destinationURL = URL(fileURLWithPath: "/tmp/export.pdf")
        var state = RhwpStudioPDFExportState.idle

        XCTAssertTrue(state.beginChoosingDestination(for: staleRequest))
        state.invalidatePendingRequestForDocumentChange()
        XCTAssertTrue(state.beginChoosingDestination(for: currentRequest))

        XCTAssertFalse(
            state.beginCollectingPages(
                for: staleRequest,
                destinationURL: destinationURL,
                currentLoadID: currentRequest.loadID
            )
        )
        XCTAssertEqual(state, .choosingDestination(currentRequest))
    }

    func testOnlyMatchingRequestCanFailCollectionOrFinishExport() {
        let request = RhwpStudioPDFExportRequest(id: 7, loadID: 20)
        let destinationURL = URL(fileURLWithPath: "/tmp/export.pdf")
        var state = RhwpStudioPDFExportState.idle

        XCTAssertTrue(state.beginChoosingDestination(for: request))
        XCTAssertTrue(
            state.beginCollectingPages(
                for: request,
                destinationURL: destinationURL,
                currentLoadID: request.loadID
            )
        )
        XCTAssertFalse(state.failCollection(requestID: request.id + 1))
        XCTAssertEqual(state.beginExporting(requestID: request.id), destinationURL)
        XCTAssertFalse(state.finishExport(requestID: request.id + 1))
        XCTAssertEqual(state, .exporting(requestID: request.id))
        XCTAssertTrue(state.finishExport(requestID: request.id))
        XCTAssertEqual(state, .idle)
    }
}
