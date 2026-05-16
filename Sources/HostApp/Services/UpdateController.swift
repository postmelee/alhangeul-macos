import Combine
import Sparkle
import SwiftUI

@MainActor
final class UpdateController: ObservableObject {
    @Published private(set) var canCheckForUpdates = false

    private let updaterController: SPUStandardUpdaterController
    private var canCheckForUpdatesObserver: AnyCancellable?

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

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
