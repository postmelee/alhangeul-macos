import Foundation

protocol RhwpStudioPrintControlling: AnyObject {
    /// Starts one print operation.
    ///
    /// Implementations must invoke `completion` exactly once after success,
    /// failure, or user cancellation.
    @MainActor
    func print(payload: RhwpStudioPagePayload, completion: @escaping () -> Void)
}

@MainActor
final class RhwpStudioPrintLifecycle {
    typealias ControllerFactory = @MainActor () -> any RhwpStudioPrintControlling

    private let controllerFactory: ControllerFactory
    private var activeController: (any RhwpStudioPrintControlling)?

    init(controllerFactory: @escaping ControllerFactory) {
        self.controllerFactory = controllerFactory
    }

    @discardableResult
    func start(
        payload: RhwpStudioPagePayload,
        onRejected: (RhwpStudioPrintLifecycleError) -> Void
    ) -> Bool {
        guard activeController == nil else {
            onRejected(.printingInProgress)
            return false
        }

        let controller = controllerFactory()
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
