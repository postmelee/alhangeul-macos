import AppKit

enum DocumentCloseConfirmationResult {
    case confirmed
    case cancelled
}

@MainActor
final class DocumentCloseConfirmationController: NSObject, NSWindowDelegate {
    private weak var window: NSWindow?
    private weak var store: DocumentViewerStore?
    private weak var previousDelegate: NSWindowDelegate?
    private var isPresentingConfirmation = false
    private var bypassNextClose = false

    func attach(window: NSWindow, store: DocumentViewerStore) {
        if self.window === window {
            self.store = store
            if window.delegate !== self {
                previousDelegate = window.delegate
                window.delegate = self
            }
            DocumentCloseConfirmationRegistry.register(self, for: window)
            return
        }

        detach(restorePreviousDelegate: true)
        self.window = window
        self.store = store
        previousDelegate = window.delegate
        window.delegate = self
        DocumentCloseConfirmationRegistry.register(self, for: window)
    }

    func detach(restorePreviousDelegate: Bool) {
        if let window {
            DocumentCloseConfirmationRegistry.unregister(window)
        }

        if restorePreviousDelegate,
           let window,
           window.delegate === self {
            window.delegate = previousDelegate
        }

        window = nil
        store = nil
        previousDelegate = nil
        isPresentingConfirmation = false
        bypassNextClose = false
    }

    func closeWithoutPrompt() {
        guard let window else {
            return
        }

        bypassNextClose = true
        window.close()
    }

    var hasUnsavedChanges: Bool {
        window != nil && store?.hasUnsavedChanges == true
    }

    func confirmForTermination(completion: @escaping (DocumentCloseConfirmationResult) -> Void) {
        guard let window,
              let store,
              store.hasUnsavedChanges
        else {
            completion(.confirmed)
            return
        }

        guard !isPresentingConfirmation else {
            completion(.cancelled)
            return
        }

        isPresentingConfirmation = true
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        presentConfirmation(for: window, store: store, completion: completion)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if bypassNextClose {
            bypassNextClose = false
            return true
        }

        if previousDelegate?.windowShouldClose?(sender) == false {
            return false
        }

        guard let store,
              store.hasUnsavedChanges
        else {
            return true
        }

        guard !isPresentingConfirmation else {
            return false
        }

        isPresentingConfirmation = true
        presentConfirmation(for: sender, store: store) { [weak self] result in
            guard let self else {
                return
            }

            if case .confirmed = result {
                self.closeWithoutPrompt()
            }
        }
        return false
    }

    func windowWillClose(_ notification: Notification) {
        previousDelegate?.windowWillClose?(notification)
        detach(restorePreviousDelegate: false)
    }

    override func responds(to selector: Selector!) -> Bool {
        super.responds(to: selector) || (previousDelegate?.responds(to: selector) ?? false)
    }

    override func forwardingTarget(for selector: Selector!) -> Any? {
        if previousDelegate?.responds(to: selector) == true {
            return previousDelegate
        }
        return super.forwardingTarget(for: selector)
    }

    private func presentConfirmation(
        for window: NSWindow,
        store: DocumentViewerStore,
        completion: @escaping (DocumentCloseConfirmationResult) -> Void
    ) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "변경사항을 저장할까요?"
        alert.informativeText = informativeText(for: store)
        alert.addButton(withTitle: "저장")
        alert.addButton(withTitle: "저장하지 않음")
        alert.addButton(withTitle: "취소")

        alert.beginSheetModal(for: window) { [weak self, weak window, weak store] response in
            Task { @MainActor in
                guard let self,
                      let window,
                      let store
                else {
                    return
                }

                self.handleConfirmationResponse(
                    response,
                    window: window,
                    store: store,
                    completion: completion
                )
            }
        }
    }

    private func informativeText(for store: DocumentViewerStore) -> String {
        let filename = store.filename.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = filename.isEmpty ? "현재 문서" : filename
        return "\"\(displayName)\" 문서에 저장되지 않은 변경사항이 있습니다. 닫기 전에 저장하시겠습니까?"
    }

    private func handleConfirmationResponse(
        _ response: NSApplication.ModalResponse,
        window: NSWindow,
        store: DocumentViewerStore,
        completion: @escaping (DocumentCloseConfirmationResult) -> Void
    ) {
        switch response {
        case .alertFirstButtonReturn:
            saveForConfirmation(window: window, store: store, completion: completion)
        case .alertSecondButtonReturn:
            store.clearUnsavedChanges()
            isPresentingConfirmation = false
            completion(.confirmed)
        default:
            isPresentingConfirmation = false
            completion(.cancelled)
        }
    }

    private func saveForConfirmation(
        window: NSWindow,
        store: DocumentViewerStore,
        completion: @escaping (DocumentCloseConfirmationResult) -> Void
    ) {
        let didStartSave = RhwpStudioNativeCommandDispatcher.saveDocument(in: window) { [weak self, weak window] result in
            Task { @MainActor in
                guard let self else {
                    return
                }

                self.isPresentingConfirmation = false
                switch result {
                case .saved:
                    completion(.confirmed)
                case .cancelled:
                    completion(.cancelled)
                case .failed(let message):
                    store.setWebViewError(message)
                    window?.makeKeyAndOrderFront(nil)
                    completion(.cancelled)
                }
            }
        }

        guard didStartSave else {
            store.setWebViewError("저장할 viewer를 찾을 수 없습니다.")
            isPresentingConfirmation = false
            completion(.cancelled)
            return
        }
    }
}

@MainActor
enum DocumentCloseConfirmationRegistry {
    private static var controllers: [ObjectIdentifier: WeakDocumentCloseConfirmationController] = [:]

    static func register(_ controller: DocumentCloseConfirmationController, for window: NSWindow) {
        cleanup()
        controllers[ObjectIdentifier(window)] = WeakDocumentCloseConfirmationController(controller)
    }

    static func unregister(_ window: NSWindow) {
        controllers.removeValue(forKey: ObjectIdentifier(window))
        cleanup()
    }

    static func dirtyControllers() -> [DocumentCloseConfirmationController] {
        cleanup()

        let orderedControllers = NSApp.windows.compactMap { window in
            controllers[ObjectIdentifier(window)]?.controller
        }
        let orderedIDs = Set(orderedControllers.map(ObjectIdentifier.init))
        let remainingControllers = controllers.values
            .compactMap(\.controller)
            .filter { !orderedIDs.contains(ObjectIdentifier($0)) }

        return (orderedControllers + remainingControllers)
            .filter(\.hasUnsavedChanges)
    }

    private static func cleanup() {
        controllers = controllers.filter { _, value in
            value.controller != nil
        }
    }
}

private final class WeakDocumentCloseConfirmationController {
    weak var controller: DocumentCloseConfirmationController?

    init(_ controller: DocumentCloseConfirmationController) {
        self.controller = controller
    }
}
