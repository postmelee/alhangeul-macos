import SwiftUI

// macOS 14+는 Settings Scene 환경에서 제공하는 공개 action으로 연다.
struct AppSettingsOpener: View {
    var body: some View {
        if #available(macOS 14, *) { ModernAppSettingsOpener() }
    }
}

@available(macOS 14, *)
private struct ModernAppSettingsOpener: View {
    @Environment(\.openSettings) private var openSettings
    @State private var id = UUID()

    var body: some View {
        Color.clear
            .allowsHitTesting(false)
            .onAppear { AppSettingsNavigation.shared.register(id) { openSettings() } }
            .onDisappear { AppSettingsNavigation.shared.unregister(id) }
    }
}
