import XCTest

@MainActor
final class RhwpStudioPrintLifecycleTests: XCTestCase {
    func testDuplicateRequestKeepsActiveControllerAndReportsErrorWithoutCreatingAnother() throws {
        let firstController = FakePrintController()
        let secondController = FakePrintController()
        var factoryCallCount = 0
        let lifecycle = RhwpStudioPrintLifecycle {
            defer { factoryCallCount += 1 }
            return factoryCallCount == 0 ? firstController : secondController
        }
        let payload = try makePayload(fileName: "first.hwp")
        var errors: [RhwpStudioPrintLifecycleError] = []

        XCTAssertTrue(lifecycle.start(payload: payload, onRejected: { errors.append($0) }))
        XCTAssertFalse(lifecycle.start(payload: payload, onRejected: { errors.append($0) }))

        XCTAssertEqual(factoryCallCount, 1)
        XCTAssertEqual(firstController.printCallCount, 1)
        XCTAssertEqual(firstController.lastFileName, "first.hwp")
        XCTAssertEqual(secondController.printCallCount, 0)
        XCTAssertEqual(errors, [.printingInProgress])
        XCTAssertEqual(errors.first?.localizedDescription, "인쇄가 이미 진행 중입니다.")
    }

    func testOnlyMatchingControllerCompletionReleasesCurrentController() throws {
        let firstController = FakePrintController()
        let secondController = FakePrintController()
        var controllers: [FakePrintController] = [firstController, secondController]
        var factoryCallCount = 0
        let lifecycle = RhwpStudioPrintLifecycle {
            factoryCallCount += 1
            return controllers.removeFirst()
        }
        let payload = try makePayload()
        var errors: [RhwpStudioPrintLifecycleError] = []

        XCTAssertTrue(lifecycle.start(payload: payload, onRejected: { errors.append($0) }))
        firstController.complete()
        XCTAssertTrue(lifecycle.start(payload: payload, onRejected: { errors.append($0) }))

        firstController.complete()
        XCTAssertFalse(lifecycle.start(payload: payload, onRejected: { errors.append($0) }))

        XCTAssertEqual(factoryCallCount, 2)
        XCTAssertEqual(secondController.printCallCount, 1)
        XCTAssertEqual(errors, [.printingInProgress])

        secondController.complete()
        controllers.append(FakePrintController())
        XCTAssertTrue(lifecycle.start(payload: payload, onRejected: { errors.append($0) }))
        XCTAssertEqual(factoryCallCount, 3)
    }

    func testCompletionAllowsNextRequestForEveryControllerOutcome() throws {
        let controllers = (0..<3).map { _ in FakePrintController() }
        var nextControllerIndex = 0
        let lifecycle = RhwpStudioPrintLifecycle {
            defer { nextControllerIndex += 1 }
            return controllers[nextControllerIndex]
        }
        let payload = try makePayload()
        var errors: [RhwpStudioPrintLifecycleError] = []

        for controller in controllers {
            XCTAssertTrue(lifecycle.start(payload: payload, onRejected: { errors.append($0) }))
            controller.complete()
        }

        XCTAssertEqual(nextControllerIndex, controllers.count)
        XCTAssertTrue(errors.isEmpty)
        XCTAssertEqual(controllers.map(\.printCallCount), [1, 1, 1])
    }

    func testImmediateRequestAfterCompletionKeepsNewControllerIdentity() throws {
        let firstController = FakePrintController()
        let secondController = FakePrintController()
        let thirdController = FakePrintController()
        var controllers = [firstController, secondController, thirdController]
        let lifecycle = RhwpStudioPrintLifecycle {
            controllers.removeFirst()
        }
        let payload = try makePayload()
        var errors: [RhwpStudioPrintLifecycleError] = []

        XCTAssertTrue(lifecycle.start(payload: payload, onRejected: { errors.append($0) }))
        firstController.complete {
            // The lifecycle completion returned while the controller's
            // `complete` call remains active.
            XCTAssertTrue(
                lifecycle.start(payload: payload, onRejected: { errors.append($0) })
            )
            firstController.complete()
            XCTAssertFalse(
                lifecycle.start(payload: payload, onRejected: { errors.append($0) })
            )
        }

        XCTAssertEqual(firstController.printCallCount, 1)
        XCTAssertEqual(secondController.printCallCount, 1)
        XCTAssertEqual(thirdController.printCallCount, 0)
        XCTAssertEqual(errors, [.printingInProgress])

        secondController.complete()
        XCTAssertTrue(lifecycle.start(payload: payload, onRejected: { errors.append($0) }))
        XCTAssertEqual(thirdController.printCallCount, 1)
    }

    func testLifecycleAndControllerDoNotRetainEachOtherAfterLifecycleRelease() throws {
        weak var weakLifecycle: RhwpStudioPrintLifecycle?
        weak var weakController: FakePrintController?

        do {
            let controller = FakePrintController()
            let lifecycle = RhwpStudioPrintLifecycle { controller }
            weakLifecycle = lifecycle
            weakController = controller

            XCTAssertTrue(
                lifecycle.start(payload: try makePayload(), onRejected: { _ in })
            )
        }

        XCTAssertNil(weakLifecycle)
        XCTAssertNil(weakController)
    }

    private func makePayload(fileName: String = "sample.hwp") throws -> RhwpStudioPagePayload {
        try RhwpStudioPagePayload(
            fileName: fileName,
            pageCount: 1,
            pages: ["<svg xmlns=\"http://www.w3.org/2000/svg\"></svg>"]
        )
    }
}

@MainActor
private final class FakePrintController: RhwpStudioPrintControlling {
    private(set) var printCallCount = 0
    private(set) var lastFileName: String?
    private var completion: (() -> Void)?

    func print(payload: RhwpStudioPagePayload, completion: @escaping () -> Void) {
        printCallCount += 1
        lastFileName = payload.fileName
        self.completion = completion
    }

    func complete() {
        completion?()
    }

    func complete(then action: () -> Void) {
        completion?()
        action()
    }
}
