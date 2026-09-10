import XCTest

final class RhwpStudioEditorSessionTests: XCTestCase {
    private func snapshot(
        loadID: Int = 3, sequence: Int = 1, epoch: Int = 1,
        changeSeq: Int = 0, dirty: Bool = false, pageCount: Int = 1, ready: Bool = true
    ) -> RhwpStudioEditorSnapshot {
        .init(loadID: loadID, sequence: sequence, documentEpoch: epoch,
              changeSeq: changeSeq, dirty: dirty, ready: ready, pageCount: pageCount, format: "hwp")
    }

    func testReadyEditorWithoutNativeBytesRegistersAndTracksEdits() throws {
        let initial = try XCTUnwrap(RhwpStudioEditorSession.accepting(
            snapshot(), after: nil, loadID: 3, hasNativeDocument: false
        ))
        XCTAssertEqual(initial.sourceBinding, .editorOnly)
        XCTAssertFalse(initial.snapshot.dirty)
        let edited = try XCTUnwrap(RhwpStudioEditorSession.accepting(
            snapshot(sequence: 2, changeSeq: 1, dirty: true), after: initial,
            loadID: 3, hasNativeDocument: false
        ))
        XCTAssertTrue(edited.snapshot.dirty)
        XCTAssertEqual(edited.snapshot.documentEpoch, initial.snapshot.documentEpoch)
    }

    func testReplacementDetachesSourceAndLateNativeMetadataCannotReattachIt() throws {
        let file = try XCTUnwrap(RhwpStudioEditorSession.accepting(
            snapshot(), after: nil, loadID: 3, hasNativeDocument: true
        ))
        XCTAssertEqual(file.sourceBinding, .nativeLoad)
        let new = try XCTUnwrap(RhwpStudioEditorSession.accepting(
            snapshot(sequence: 2, epoch: 2), after: file, loadID: 3, hasNativeDocument: true
        ))
        XCTAssertEqual(new.sourceBinding, .editorOnly)
        let edited = RhwpStudioEditorSession.accepting(
            snapshot(sequence: 3, epoch: 2, changeSeq: 1, dirty: true), after: new,
            loadID: 3, hasNativeDocument: true
        )
        XCTAssertEqual(edited?.sourceBinding, .editorOnly)
        XCTAssertNil(RhwpStudioEditorSession.accepting(
            snapshot(sequence: 4, epoch: 1, changeSeq: 99, dirty: true), after: new,
            loadID: 3, hasNativeDocument: true
        ))
    }

    func testCancelAndCleanSynchronizationPreserveSource() throws {
        let file = try XCTUnwrap(RhwpStudioEditorSession.accepting(
            snapshot(sequence: 3, changeSeq: 2, dirty: true), after: nil,
            loadID: 3, hasNativeDocument: true
        ))
        let cancelled = RhwpStudioEditorSession.accepting(
            snapshot(sequence: 4, changeSeq: 2, dirty: true), after: file,
            loadID: 3, hasNativeDocument: true
        )
        XCTAssertEqual(cancelled?.sourceBinding, .nativeLoad)
        XCTAssertTrue(cancelled?.snapshot.dirty == true)
        let saved = RhwpStudioEditorSession.accepting(
            snapshot(sequence: 5, changeSeq: 2), after: cancelled,
            loadID: 3, hasNativeDocument: true
        )
        XCTAssertEqual(saved?.sourceBinding, .nativeLoad)
        XCTAssertFalse(saved?.snapshot.dirty == true)
    }

    func testRejectsOldLoadDuplicateOutOfOrderAndInvalidSnapshots() throws {
        let current = try XCTUnwrap(RhwpStudioEditorSession.accepting(
            snapshot(sequence: 5, changeSeq: 3), after: nil, loadID: 3, hasNativeDocument: true
        ))
        for stale in [snapshot(loadID: 2, sequence: 9), snapshot(sequence: 5, changeSeq: 3),
                      snapshot(sequence: 4, changeSeq: 3), snapshot(sequence: 6, changeSeq: 2),
                      snapshot(sequence: 6, changeSeq: 3, pageCount: 0)] {
            XCTAssertNil(RhwpStudioEditorSession.accepting(
                stale, after: current, loadID: 3, hasNativeDocument: true
            ))
        }
        let reload = RhwpStudioEditorSession.accepting(
            snapshot(loadID: 4), after: current, loadID: 4, hasNativeDocument: true
        )
        XCTAssertEqual(reload?.sourceBinding, .nativeLoad)
    }
    func testConfirmedCreationUsesNewBindingAndRecoveryRemovesIt() throws {
        var created = snapshot()
        created.createdByEditor = true
        let initial = try XCTUnwrap(RhwpStudioEditorSession.accepting(
            created, after:nil, loadID:3, hasNativeDocument:false))
        XCTAssertEqual(initial.sourceBinding, .newDocument)
        var typed = snapshot(sequence:2, changeSeq:1, dirty:true)
        typed.createdByEditor = true
        let edited = try XCTUnwrap(RhwpStudioEditorSession.accepting(
            typed, after:initial, loadID:3, hasNativeDocument:false))
        XCTAssertEqual(edited.sourceBinding, .newDocument)
        let recovered = RhwpStudioEditorSession.accepting(
            snapshot(sequence:3, epoch:2, changeSeq:1, dirty:true), after:edited,
            loadID:3, hasNativeDocument:false)
        XCTAssertEqual(recovered?.sourceBinding, .editorOnly)
        let saved = RhwpStudioEditorSession(snapshot:created, sourceBinding:.nativeLoad)
        XCTAssertEqual(RhwpStudioEditorSession.accepting(typed, after:saved, loadID:3,
            hasNativeDocument:true)?.sourceBinding, .nativeLoad)
    }

    func testConfirmedReplacementClearsNativeBindingAndLostObservationIsConservative() throws {
        let file = RhwpStudioEditorSession(snapshot:snapshot(), sourceBinding:.nativeLoad)
        var created = snapshot(sequence:2, epoch:2)
        created.createdByEditor = true
        let new = try XCTUnwrap(RhwpStudioEditorSession.accepting(created, after:file,
            loadID:3, hasNativeDocument:true))
        XCTAssertEqual(new.sourceBinding, .newDocument)
        let unknown = RhwpStudioEditorSession.accepting(snapshot(sequence:3, epoch:2), after:new,
            loadID:3, hasNativeDocument:true)
        XCTAssertEqual(unknown?.sourceBinding, .editorOnly)
    }

}
