import Combine
import Sparkle
import SwiftUI

@MainActor
final class UpdateController: ObservableObject {
    @Published private(set) var canCheckForUpdates = false

    private let updaterController: SPUStandardUpdaterController
    private let analyticsUpdaterDelegate: AppExecutionSparkleUpdaterDelegate
    private var canCheckForUpdatesObserver: AnyCancellable?

    init() {
        let analyticsUpdaterDelegate = AppExecutionSparkleUpdaterDelegate(
            observer: AppExecutionSparkleUpdateObserver(
                stateStore: AppExecutionAnalyticsRuntime.shared.stateStore
            )
        )
        self.analyticsUpdaterDelegate = analyticsUpdaterDelegate
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: analyticsUpdaterDelegate,
            userDriverDelegate: nil
        )
        requestLaunchUpdateCheckIfAllowed()

        canCheckForUpdatesObserver = updaterController.updater
            .publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .sink { [weak self] canCheckForUpdates in
                self?.canCheckForUpdates = canCheckForUpdates
            }
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    private func requestLaunchUpdateCheckIfAllowed() {
        guard updaterController.updater.automaticallyChecksForUpdates else {
            return
        }

        updaterController.updater.checkForUpdatesInBackground()
    }
}

@MainActor
private final class AppExecutionSparkleUpdaterDelegate: NSObject, SPUUpdaterDelegate {
    private let observer: AppExecutionSparkleUpdateObserver

    init(observer: AppExecutionSparkleUpdateObserver) {
        self.observer = observer
    }

    func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        observer.willInstallUpdate(
            fromVersion: BuildInfo.version,
            displayVersion: item.displayVersionString
        )
    }
}

struct CheckForUpdatesCommand: View {
    @ObservedObject var updateController: UpdateController

    var body: some View {
        Button("업데이트 확인...") {
            updateController.checkForUpdates()
        }
        .disabled(!updateController.canCheckForUpdates)
    }
}
