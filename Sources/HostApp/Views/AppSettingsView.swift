import SwiftUI

struct AppSettingsView: View {
    @ObservedObject private var navigation = AppSettingsNavigation.shared
    @ObservedObject var analytics: AppExecutionAnalyticsSettingsModel
    @ObservedObject var fonts: FontLibrarySettingsModel

    @ObservedObject var installedFonts: InstalledFontSettingsModel

    var body: some View {
        TabView(selection: $navigation.selectedTab) {
            AppExecutionAnalyticsSettingsView(model: analytics)
                .tabItem { Label("개인정보", systemImage: "hand.raised") }
                .tag(AppSettingsNavigation.Tab.privacy)
            InstalledFontSettingsView(model: installedFonts, library: fonts)
                .tabItem { Label("글꼴", systemImage: "textformat") }
                .tag(AppSettingsNavigation.Tab.fonts)
        }
        .frame(width: 720, height: 560)
    }
}
