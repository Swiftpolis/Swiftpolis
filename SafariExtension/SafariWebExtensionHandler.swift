import Foundation
import SafariServices
import SwiftpolisBridge
import os

/// Safari sends the extension's native messages here, inside this sandboxed extension. It passes any
/// links to the app through the inbox they share.
final class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
    private static let logger = Logger(subsystem: "com.amirabravesh.Swiftpolis.Extension", category: "Browser")

    func beginRequest(with context: NSExtensionContext) {
        let item = context.inputItems.first as? NSExtensionItem
        let message = item?.userInfo?[SFExtensionMessageKey] as? [String: Any] ?? [:]
        let links = BrowserMessage.links(fromMessage: message)

        var delivered = true
        if !links.isEmpty {
            delivered = deliver(links)
        }

        let response = NSExtensionItem()
        response.userInfo = [SFExtensionMessageKey: ["enable": true, "delivered": delivered]]
        context.completeRequest(returningItems: [response], completionHandler: nil)
    }

    private func deliver(_ links: [BrowserLink]) -> Bool {
        guard let inbox = BrowserInbox.shared else {
            Self.logger.error("The shared folder isn't available")
            return false
        }
        do {
            try inbox.write(links)
            BrowserInbox.wakeApp()
            return true
        } catch {
            Self.logger.error("Couldn't save links: \(error.localizedDescription)")
            return false
        }
    }
}
