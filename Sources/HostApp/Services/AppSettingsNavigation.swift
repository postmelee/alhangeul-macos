import AppKit
import Combine

@MainActor
final class AppSettingsNavigation: ObservableObject {
    enum Tab: Hashable { case privacy, fonts }
    static let shared = AppSettingsNavigation()
    @Published var selectedTab: Tab = .privacy
    private var openers: [(id: UUID, open: () -> Void)] = []

    func register(_ id: UUID, open: @escaping () -> Void) {
        unregister(id)
        openers.append((id, open))
    }

    func unregister(_ id: UUID) { openers.removeAll { $0.id == id } }

    @discardableResult
    func openFonts() -> Bool {
        selectedTab = .fonts
        if #available(macOS 14, *) {
            guard let opener = openers.last else { return false }
            opener.open()
            return true
        }
        let selector = NSSelectorFromString(ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 13
            ? "showSettingsWindow:" : "showPreferencesWindow:")
        return NSApp.sendAction(selector, to: nil, from: nil)
    }
}
