import Foundation
import XCTest

final class DocumentOpenRecoveryTests: XCTestCase {
    func testFailureSanitizesFilenameAndBuildsUserMessage() {
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let failure = RecoverableDocumentOpenFailure(
            id: id,
            source: .fileDrop,
            filename: "  /private/tmp/example.pdf  ",
            reason: "이 파일은 HWP/HWPX 형식이 아니거나 손상되었습니다."
        )

        XCTAssertEqual(failure.id, id)
        XCTAssertEqual(failure.source, .fileDrop)
        XCTAssertEqual(failure.filename, "example.pdf")
        XCTAssertEqual(failure.title, "끌어놓은 문서를 열 수 없습니다")
        XCTAssertEqual(
            failure.message,
            "파일: example.pdf\n이 파일은 HWP/HWPX 형식이 아니거나 손상되었습니다."
        )
    }

    func testFailureOmitsBlankFilename() {
        let failure = RecoverableDocumentOpenFailure(
            source: .externalOpen,
            filename: " \n ",
            reason: "문서를 읽을 수 없습니다."
        )

        XCTAssertNil(failure.filename)
        XCTAssertEqual(failure.message, "문서를 읽을 수 없습니다.")
    }

    func testSourceTitlesCoverEveryOpeningPath() {
        XCTAssertEqual(DocumentOpenSource.allCases.count, 5)
        XCTAssertEqual(DocumentOpenSource.filePanel.failureTitle, "문서를 열 수 없습니다")
        XCTAssertEqual(DocumentOpenSource.externalOpen.failureTitle, "문서를 열 수 없습니다")
        XCTAssertEqual(DocumentOpenSource.recentDocument.failureTitle, "최근 문서를 열 수 없습니다")
        XCTAssertEqual(DocumentOpenSource.fileDrop.failureTitle, "끌어놓은 문서를 열 수 없습니다")
        XCTAssertEqual(DocumentOpenSource.webViewDrop.failureTitle, "끌어놓은 문서를 열 수 없습니다")
    }

    func testBeginLoadIncrementsIDAndClearsPreviousFailure() {
        var state = DocumentOpenRecoveryState()
        let firstLoadID = state.beginLoad()
        XCTAssertTrue(
            state.failLoad(
                loadID: firstLoadID,
                failure: makeFailure(idSuffix: 1)
            )
        )

        let secondLoadID = state.beginLoad()

        XCTAssertEqual(secondLoadID, firstLoadID + 1)
        XCTAssertTrue(state.isLoading)
        XCTAssertNil(state.failure)
    }

    func testCurrentFailureStopsLoadingAndRejectsLaterCompletion() {
        var state = DocumentOpenRecoveryState()
        let loadID = state.beginLoad()
        let failure = makeFailure(idSuffix: 2)

        XCTAssertTrue(state.failLoad(loadID: loadID, failure: failure))
        XCTAssertFalse(state.isLoading)
        XCTAssertEqual(state.failure, failure)
        XCTAssertFalse(state.completeLoad(loadID: loadID))
        XCTAssertEqual(state.failure, failure)
    }

    func testStaleFailureDoesNotChangeCurrentLoad() {
        var state = DocumentOpenRecoveryState()
        let staleLoadID = state.beginLoad()
        let currentLoadID = state.beginLoad()

        XCTAssertFalse(
            state.failLoad(
                loadID: staleLoadID,
                failure: makeFailure(idSuffix: 3)
            )
        )
        XCTAssertTrue(state.isCurrent(loadID: currentLoadID))
        XCTAssertTrue(state.isLoading)
        XCTAssertNil(state.failure)
    }

    func testCurrentCompletionAllowsOneCommitAndIgnoresStaleCompletion() {
        var state = DocumentOpenRecoveryState()
        let staleLoadID = state.beginLoad()
        let currentLoadID = state.beginLoad()

        XCTAssertFalse(state.completeLoad(loadID: staleLoadID))
        XCTAssertTrue(state.isLoading)
        XCTAssertTrue(state.completeLoad(loadID: currentLoadID))
        XCTAssertFalse(state.isLoading)
        XCTAssertNil(state.failure)
        XCTAssertFalse(state.completeLoad(loadID: currentLoadID))
    }

    func testDismissClearsOnlyFailureState() {
        var state = DocumentOpenRecoveryState()
        let loadID = state.beginLoad()
        XCTAssertTrue(
            state.failLoad(
                loadID: loadID,
                failure: makeFailure(idSuffix: 4)
            )
        )

        state.dismissFailure()

        XCTAssertNil(state.failure)
        XCTAssertFalse(state.isLoading)
        XCTAssertEqual(state.activeLoadID, loadID)
    }

    func testRetryCanBeStartedOnceAndChooserCancellationDoesNotBeginLoad() {
        var state = DocumentOpenRecoveryState()
        let loadID = state.beginLoad()
        XCTAssertTrue(
            state.failLoad(
                loadID: loadID,
                failure: makeFailure(idSuffix: 5)
            )
        )

        XCTAssertTrue(state.beginRetry())
        XCTAssertFalse(state.beginRetry())
        XCTAssertNil(state.failure)
        XCTAssertFalse(state.isLoading)
        XCTAssertEqual(state.activeLoadID, loadID)
    }

    private func makeFailure(idSuffix: UInt8) -> RecoverableDocumentOpenFailure {
        let id = UUID(uuid: (
            0, 0, 0, 0,
            0, 0,
            0, 0,
            0, 0,
            0, 0, 0, 0, 0, idSuffix
        ))
        return RecoverableDocumentOpenFailure(
            id: id,
            source: .filePanel,
            filename: "document.hwp",
            reason: "문서를 열 수 없습니다."
        )
    }
}
