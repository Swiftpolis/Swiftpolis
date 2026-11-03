import SwiftUI
import SwiftpolisBridge
import SwiftpolisEngines
import UIKit

@main
struct SwiftpolisMobileApp: App {
    @UIApplicationDelegateAdaptor(MobileAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView(model: MobileModel.shared)
        }
    }
}

final class MobileAppDelegate: NSObject, UIApplicationDelegate {
    /// iOS can launch the app with no window just to report on its downloads, so this can't wait for one.
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        Task { await MobileModel.shared.start() }
        listenForSharedLinks()
        return true
    }

    /// Coming to the front covers most sharing, but on iPad the app can already be on screen beside the
    /// other app. Left in the background, links stay safely in the inbox until the app comes to the front.
    private func listenForSharedLinks() {
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            nil,
            { _, _, _, _, _ in
                Task { @MainActor in
                    if UIApplication.shared.applicationState != .background {
                        MobileModel.shared.checkInbox()
                    }
                }
            },
            BrowserInbox.wakeNotification as CFString,
            nil,
            .deliverImmediately
        )
    }

    /// iOS suspends the app again once this is called, so saving and notifying get a moment first.
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        nonisolated(unsafe) let completion = completionHandler
        MobileModel.shared.transfers.setBackgroundCompletion {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                completion()
            }
        }
    }
}
