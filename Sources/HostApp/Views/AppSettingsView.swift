import SwiftUI

struct AppSettingsView: View {
    @ObservedObject var analytics: AppExecutionAnalyticsSettingsModel
    @ObservedObject var fonts: FontLibrarySettingsModel

    var body: some View {
        TabView {
            AppExecutionAnalyticsSettingsView(model: analytics)
                .tabItem { Label("개인정보", systemImage: "hand.raised") }
            FontLibrarySettingsView(model: fonts)
                .tabItem { Label("글꼴", systemImage: "textformat") }
        }
        .frame(width: 720, height: 560)
    }
}
