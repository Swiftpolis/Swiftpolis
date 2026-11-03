import CFNetwork
import Foundation

enum SystemProxy {
    /// The HTTP proxy set in System Settings, for the Add Link window's Detect button.
    static func detect() -> (host: String, port: Int)? {
        guard let settings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any],
              (settings[kCFNetworkProxiesHTTPEnable as String] as? Int) == 1,
              let host = settings[kCFNetworkProxiesHTTPProxy as String] as? String,
              let port = settings[kCFNetworkProxiesHTTPPort as String] as? Int
        else { return nil }
        return (host, port)
    }
}
