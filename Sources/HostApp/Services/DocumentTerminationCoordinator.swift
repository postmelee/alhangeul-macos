import AppKit

@MainActor
final class DocumentTerminationCoordinator {
    static let shared = DocumentTerminationCoordinator()

    private var isConfirmingTermination = false
    private var didReplyToCurrentRequest = false

    private init() {}

    func applicationShouldTerminate(_ application: NSApplication) -> NSApplication.TerminateReply {
        guard !isConfirmingTermination else {
            return .terminateCancel
        }

        let dirtyControllers = DocumentCloseConfirmationRegistry.dirtyControllers()
        guard !dirtyControllers.isEmpty else {
            return .terminateNow
        }

        isConfirmingTermination = true
        didReplyToCurrentRequest = false
        confirmNext(
            dirtyControllers,
            at: 0,
            application: application
        )
        return .terminateLater
    }

    private func confirmNext(
        _ controllers: [DocumentCloseConfirmationController],
        at index: Int,
        application: NSApplication
    ) {
        guard index < controllers.count else {
            finish(application: application, shouldTerminate: true)
            return
        }

        let controller = controllers[index]
        guard controller.hasUnsavedChanges else {
            confirmNext(controllers, at: index + 1, application: application)
            return
        }

        controller.confirmForTermination { [weak self, weak application] result in
            guard let self,
                  let application
            else {
                return
            }

            switch result {
            case .confirmed:
                self.confirmNext(controllers, at: index + 1, application: application)
            case .cancelled:
                self.finish(application: application, shouldTerminate: false)
            }
        }
    }

    private func finish(application: NSApplication, shouldTerminate: Bool) {
        guard isConfirmingTermination,
              !didReplyToCurrentRequest
        else {
            return
        }

        didReplyToCurrentRequest = true
        isConfirmingTermination = false
        application.reply(toApplicationShouldTerminate: shouldTerminate)
    }
}
