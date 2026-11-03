import AppKit
import SwiftpolisEngines
import SwiftpolisServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Registered directly because SwiftUI's app lifecycle doesn't pass links to a delegate here,
        // and because this works whichever windows are open.
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleLink(_:replyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
        Task { await AppModel.shared.start() }
        #if DEBUG
        DebugAutomation.run()
        #endif
    }

    /// A browser's helper has left something in the inbox. The link itself carries nothing.
    @objc private func handleLink(_ event: NSAppleEventDescriptor, replyEvent: NSAppleEventDescriptor) {
        AppModel.shared.drainInbox()
    }

    /// With "hide window on close" on, closing the window leaves the app running in the menu bar.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        !AppModel.shared.preferences.hidesWindowOnClose
    }

    /// A helper would otherwise carry on with nobody listening to it.
    func applicationWillTerminate(_ notification: Notification) {
        HelperProcess.terminateAll()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard AppModel.shared.hasActiveDownloads else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "A download or downloads are in progress."
        alert.informativeText = "Stop them before closing the app!"
        alert.alertStyle = .warning
        alert.runModal()
        return .terminateCancel
    }
}
