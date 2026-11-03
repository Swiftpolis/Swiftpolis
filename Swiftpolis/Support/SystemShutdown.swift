import Foundation

enum SystemShutdown {
    /// Asks macOS to shut down, with no root password. The first time, macOS asks whether Swiftpolis
    /// may control System Events. Returns a message if it didn't work.
    static func perform() -> String? {
        let script = NSAppleScript(source: "tell application \"System Events\" to shut down")
        var error: NSDictionary?
        script?.executeAndReturnError(&error)
        return error?[NSAppleScript.errorMessage] as? String
    }
}
