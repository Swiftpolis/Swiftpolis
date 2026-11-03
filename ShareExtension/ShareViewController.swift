import SwiftUI
import SwiftpolisBridge
import UIKit
import UniformTypeIdentifiers
import UserNotifications

/// Takes what another app shared and leaves any links in the inbox, for the app to find when it next
/// comes to the front. iOS doesn't let a share extension open its app, so the most this can do is say so.
final class ShareViewController: UIViewController {
    private let result = ShareResult()

    override func viewDidLoad() {
        super.viewDidLoad()
        let host = UIHostingController(rootView: ShareResultView(result: result) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        })
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)

        Task { result.state = await send() }
    }

    private func send() async -> ShareResult.State {
        let items = extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []
        let links = await SharedItems.links(in: items)
        guard !links.isEmpty else { return .noLinks }
        guard let inbox = BrowserInbox.shared,
              (try? inbox.write(links.map { BrowserLink(url: $0) })) != nil
        else { return .failed }
        BrowserInbox.wakeApp()
        announce(count: links.count)
        return .sent(count: links.count)
    }

    /// Tapping this is the way back to the app. It only shows if the app was allowed to notify, and iOS
    /// holds it back if the app is on screen, where the links are already showing.
    private func announce(count: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Links ready to add"
        content.body = ShareResult.waitingMessage(count: count)
        content.threadIdentifier = "shared-links"
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: BrowserInbox.waitingNotificationID, content: content, trigger: nil)
        )
    }
}

enum SharedItems {
    static func links(in items: [NSExtensionItem]) async -> [String] {
        var texts: [String] = []
        var urls: [String] = []
        for provider in items.flatMap({ $0.attachments ?? [] }) {
            if let url = await text(of: .url, from: provider) {
                urls.append(url)
            } else if let text = await text(of: .plainText, from: provider) {
                texts.append(text)
            }
        }
        return LinkText.links(sharedTexts: texts, urls: urls)
    }

    /// Asking for the item as it was registered, because Safari's selected text doesn't load as a String
    /// object, though the provider says it can.
    private static func text(of type: UTType, from provider: NSItemProvider) async -> String? {
        guard provider.hasItemConformingToTypeIdentifier(type.identifier) else { return nil }
        return await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: type.identifier) { item, _ in
                let text: String? = switch item {
                case let url as URL: url.absoluteString
                case let text as String: text
                case let text as NSAttributedString: text.string
                case let data as Data: String(data: data, encoding: .utf8)
                default: nil
                }
                continuation.resume(returning: text)
            }
        }
    }
}

@Observable
final class ShareResult {
    enum State {
        case sending
        case sent(count: Int)
        case noLinks
        case failed
    }

    var state = State.sending

    static func waitingMessage(count: Int) -> String {
        count == 1 ? "Open Swiftpolis to add this link." : "Open Swiftpolis to add these \(count) links."
    }
}

private struct ShareResultView: View {
    let result: ShareResult
    let done: () -> Void

    var body: some View {
        switch result.state {
        case .sending:
            ProgressView()
        case .sent(let count):
            outcome("Sent to Swiftpolis", systemImage: "checkmark.circle", message: ShareResult.waitingMessage(count: count))
        case .noLinks:
            outcome("No Links Found", systemImage: "link", message: "Swiftpolis only takes links starting with http:// or https://.")
        case .failed:
            outcome("Couldn't Send These", systemImage: "exclamationmark.triangle", message: "Copy the links, and paste them into Swiftpolis.")
        }
    }

    private func outcome(_ title: String, systemImage: String, message: String) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        } actions: {
            Button("Done", action: done)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
    }
}
