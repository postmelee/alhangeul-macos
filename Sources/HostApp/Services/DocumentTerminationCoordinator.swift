import AppKit

@MainActor
final class DocumentTerminationCoordinator {
    static let shared = DocumentTerminationCoordinator()

    private var isConfirmingTermination = false
    private var didReplyToCurrentRequest = false

    private let reply: @MainActor (NSApplication, Bool) -> Void

    init(reply: @escaping @MainActor (NSApplication, Bool) -> Void = { $0.reply(toApplicationShouldTerminate:$1) }) {
        self.reply = reply
    }

    func applicationShouldTerminate(_ application: NSApplication) -> NSApplication.TerminateReply {
        guard !isConfirmingTermination else {
            return .terminateCancel
        }

        let controllers = DocumentCloseConfirmationRegistry.controllersForTermination()
        guard !controllers.isEmpty else {
            return .terminateNow
        }

        isConfirmingTermination = true
        didReplyToCurrentRequest = false
        confirmNext(
            controllers,
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
        reply(application, shouldTerminate)
    }
}
