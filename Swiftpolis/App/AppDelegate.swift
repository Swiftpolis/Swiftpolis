import AppKit
import SwiftUI
import SwiftpolisEngines
import SwiftpolisServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// At launch there are no windows yet, which doesn't mean the last one has closed.
    private var hasSeenWindow = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Registered directly because SwiftUI's app lifecycle doesn't pass links to a delegate here,
        // and because this works whichever windows are open.
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleLink(_:replyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
        // Checked after every event, and regularly too, as a window can open with no event to follow.
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            MainActor.assumeIsolated { self.updateDockIcon() }
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateDockIcon),
            name: NSApplication.didUpdateNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose),
            name: NSWindow.willCloseNotification,
            object: nil
        )
        Task {
            await AppModel.shared.start()
            // macOS can remember that no window was open last time. Leave it a moment to restore any.
            try? await Task.sleep(for: .seconds(1))
            if !hasOpenWindows { AppModel.shared.openWindowAction?(id: WindowID.main) }
        }
        #if DEBUG
        DebugAutomation.run()
        #endif
    }

    /// A browser's helper has left something in the inbox. The link itself carries nothing.
    @objc private func handleLink(_ event: NSAppleEventDescriptor, replyEvent: NSAppleEventDescriptor) {
        AppModel.shared.drainInbox()
    }

    /// The menu bar item's own windows don't count, and they have no title bar.
    private var hasOpenWindows: Bool {
        NSApp.windows.contains { window in
            window.styleMask.contains(.titled) && (window.isVisible || window.isMiniaturized)
        }
    }

    /// The window is still open at this point, so this looks again just after.
    @objc private func windowWillClose() {
        Task { self.updateDockIcon() }
    }

    /// The Dock icon goes when the last window does, unless Preferences says to keep it.
    @objc private func updateDockIcon() {
        hasSeenWindow = hasSeenWindow || hasOpenWindows
        guard hasSeenWindow else { return }
        let shows = AppModel.shared.preferences.showsDockIcon(hasOpenWindows: hasOpenWindows)
        let policy: NSApplication.ActivationPolicy = shows ? .regular : .accessory
        if NSApp.activationPolicy() != policy { NSApp.setActivationPolicy(policy) }
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
