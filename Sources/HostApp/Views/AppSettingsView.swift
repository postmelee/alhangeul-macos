import SwiftUI

struct AppSettingsView: View {
    @ObservedObject var analytics: AppExecutionAnalyticsSettingsModel
    @ObservedObject var fonts: FontLibrarySettingsModel

    @ObservedObject var installedFonts: InstalledFontSettingsModel

    var body: some View {
        TabView {
            AppExecutionAnalyticsSettingsView(model: analytics)
                .tabItem { Label("개인정보", systemImage: "hand.raised") }
            InstalledFontSettingsView(model: installedFonts, library: fonts)
                .tabItem { Label("글꼴", systemImage: "textformat") }
        }
        .frame(width: 720, height: 560)
    }
}
