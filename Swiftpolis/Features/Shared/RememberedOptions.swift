import Foundation
import SwiftpolisDomain
import SwiftpolisServices

/// Persepolis offers the last-used proxy and login again, but never their passwords.
enum RememberedOptions {
    private static let defaults = UserDefaults.standard

    static func remember(from draft: DownloadDraft) {
        defaults.set(draft.proxyHost, forKey: "addLink.proxyHost")
        defaults.set(draft.proxyPort, forKey: "addLink.proxyPort")
        defaults.set(draft.proxyUser, forKey: "addLink.proxyUser")
        defaults.set(draft.proxyKind.rawValue, forKey: "addLink.proxyKind")
        defaults.set(draft.loginUser, forKey: "addLink.loginUser")
    }

    static func restore(into draft: inout DownloadDraft) {
        draft.proxyHost = defaults.string(forKey: "addLink.proxyHost") ?? ""
        draft.proxyPort = defaults.integer(forKey: "addLink.proxyPort")
        draft.proxyUser = defaults.string(forKey: "addLink.proxyUser") ?? ""
        draft.loginUser = defaults.string(forKey: "addLink.loginUser") ?? ""
        if let kind = defaults.string(forKey: "addLink.proxyKind").flatMap(ProxySettings.Kind.init(rawValue:)) {
            draft.proxyKind = kind
        }
    }
}
