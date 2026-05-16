import AppKit
import CoreServices
import Foundation

enum ExtensionSystemRegistrationRefresher {
    @discardableResult
    static func refreshCurrentBundle() -> OSStatus {
        refresh(appBundleURL: Bundle.main.bundleURL)
    }

    @discardableResult
    static func refresh(appBundleURL: URL) -> OSStatus {
        let registrationStatus = LSRegisterURL(appBundleURL as CFURL, true)
        NSWorkspace.shared.noteFileSystemChanged(appBundleURL.path)

        let plugInsURL = appBundleURL
            .appendingPathComponent("Contents/PlugIns", isDirectory: true)
        NSWorkspace.shared.noteFileSystemChanged(plugInsURL.path)

        for status in ExtensionStatus.allCases {
            let appexURL = plugInsURL.appendingPathComponent(status.appexBundleName, isDirectory: true)
            NSWorkspace.shared.noteFileSystemChanged(appexURL.path)
        }

        return registrationStatus
    }
}
