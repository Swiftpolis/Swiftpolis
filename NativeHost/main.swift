import Foundation
import SwiftpolisBridge

// Chrome-family browsers and Firefox start this when their extension has something to say. It answers,
// passes any links to the app through the inbox, and exits.

FileHandle.standardOutput.write(NativeMessaging.frame(NativeMessaging.reply))

guard let message = NativeMessaging.readFrame(from: .standardInput) else { exit(0) }
let links = BrowserMessage.links(from: message)
guard !links.isEmpty else { exit(0) }

guard let inbox = BrowserInbox.shared else {
    FileHandle.standardError.write(Data("Swiftpolis's shared folder isn't available.\n".utf8))
    exit(1)
}
do {
    try inbox.write(links)
    BrowserInbox.wakeApp()
} catch {
    FileHandle.standardError.write(Data("Couldn't save the links: \(error.localizedDescription)\n".utf8))
    exit(1)
}
