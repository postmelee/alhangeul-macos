import Foundation

protocol RhwpStudioPrintControlling: AnyObject {
    /// Starts one print operation.
    ///
    /// Implementations must invoke `completion` exactly once after success,
    /// failure, or user cancellation.
    @MainActor
    func print(payload: RhwpStudioPagePayload, completion: @escaping () -> Void)
    @MainActor func cancel()
}

extension RhwpStudioPrintControlling { func cancel() {} }

@MainActor
final class RhwpStudioPrintLifecycle {
    typealias ControllerFactory = @MainActor () -> any RhwpStudioPrintControlling

    private let controllerFactory: ControllerFactory
    private var activeController: (any RhwpStudioPrintControlling)?
    var isPrinting: Bool { activeController != nil }
    func cancelPreparation() { activeController?.cancel() }

    init(controllerFactory: @escaping ControllerFactory) {
        self.controllerFactory = controllerFactory
    }

    @discardableResult
    func start(
        payload: RhwpStudioPagePayload,
        controller suppliedController: (any RhwpStudioPrintControlling)? = nil,
        onFinished: @escaping @MainActor () -> Void = {},
        onRejected: (RhwpStudioPrintLifecycleError) -> Void
    ) -> Bool {
        guard activeController == nil else {
            onRejected(.printingInProgress)
            return false
        }

        let controller = suppliedController ?? controllerFactory()
        activeController = controller
        controller.print(payload: payload) { [weak self, weak controller] in
            guard let self,
                  let controller,
                  let activeController = self.activeController,
                  activeController === controller
            else {
                return
            }

            self.activeController = nil
            onFinished()
        }
        return true
    }
}

enum RhwpStudioPrintLifecycleError: LocalizedError, Equatable {
    case printingInProgress

    var errorDescription: String? {
        switch self {
        case .printingInProgress:
            "인쇄가 이미 진행 중입니다."
        }
    }
}
