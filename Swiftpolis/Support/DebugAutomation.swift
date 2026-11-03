#if DEBUG
import AppKit
import Foundation
import SwiftUI
import SwiftpolisBridge
import SwiftpolisDomain
import SwiftpolisServices

/// Lets a Debug build be checked without anyone at the keyboard. Release builds don't contain this.
///
/// - `SWIFTPOLIS_DEBUG_DATA`: a folder to keep all data in, instead of the real library, preferences
///   and Keychain. Nothing else here runs without it.
/// - `SWIFTPOLIS_DEBUG_SNAPSHOTS`: a folder to write each window to, as PNGs, once a second.
/// - `SWIFTPOLIS_DEBUG_ADD`: a link to add and start once the app is ready.
/// - `SWIFTPOLIS_DEBUG_OPEN`: window IDs to open, separated by commas.
/// - `SWIFTPOLIS_DEBUG_IMMEDIATE`: when set, links from browsers start straight away.
/// - `SWIFTPOLIS_DEBUG_SHARED_INBOX`: when set, reads the real shared inbox instead of a throwaway one.
/// - `SWIFTPOLIS_DEBUG_QUEUE`: links to add to Scheduled Downloads, separated by commas, before starting
///   it and showing it in the main window.
/// - `SWIFTPOLIS_DEBUG_VIDEO`: a link to open in Video Finder and fetch straight away.
/// - `SWIFTPOLIS_DEBUG_VIDEO_SUBMIT`: when set, Video Finder also presses OK once it has the formats.
/// - `SWIFTPOLIS_DEBUG_DOCK_CHECK`: when set, closes every window, reopens the main one the way the menu
///   bar item does, and prints the Dock state at each point.
/// - `SWIFTPOLIS_DEBUG_PASTE`: text to paste, from a private pasteboard, into the first field of the window
///   named by `SWIFTPOLIS_DEBUG_PASTE_WINDOW`. It reports which windows are open afterwards.
/// - `SWIFTPOLIS_DEBUG_BATCH_START`: a Category for the batch window to add to and start, as its Add and
///   Start button does, once it has the names. A Queue of that name is created if there isn't one.
/// - `SWIFTPOLIS_DEBUG_UPDATE`: when set, looks for a yt-dlp update as a normal launch would.
enum DebugAutomation {
    private static var data: String? { ProcessInfo.processInfo.environment["SWIFTPOLIS_DEBUG_DATA"] }

    static var isActive: Bool { data != nil }

    /// The Category the main window should open on.
    static var initialCategory: String? {
        guard isActive, ProcessInfo.processInfo.environment["SWIFTPOLIS_DEBUG_QUEUE"] != nil else { return nil }
        return CategoryKind.scheduledDownloadsName
    }

    static var fetchesVideoLinks: Bool {
        isActive && ProcessInfo.processInfo.environment["SWIFTPOLIS_DEBUG_VIDEO"] != nil
    }

    static var submitsVideoFinder: Bool {
        isActive && ProcessInfo.processInfo.environment["SWIFTPOLIS_DEBUG_VIDEO_SUBMIT"] != nil
    }

    static var batchStartCategory: String? {
        isActive ? ProcessInfo.processInfo.environment["SWIFTPOLIS_DEBUG_BATCH_START"] : nil
    }

    static var updatesHelpers: Bool {
        isActive && ProcessInfo.processInfo.environment["SWIFTPOLIS_DEBUG_UPDATE"] != nil
    }

    nonisolated static func environment() -> AppDependencies.Environment? {
        guard let data = ProcessInfo.processInfo.environment["SWIFTPOLIS_DEBUG_DATA"] else { return nil }
        let defaults = UserDefaults(suiteName: "SwiftpolisDebug-\(abs(data.hashValue))") ?? .standard
        let store = PreferencesStore(defaults: defaults)
        var preferences = Preferences()
        preferences.downloadFolder = data + "/Downloads"
        preferences.startsBrowserRequestsImmediately = ProcessInfo.processInfo.environment["SWIFTPOLIS_DEBUG_IMMEDIATE"] != nil
        store.preferences = preferences
        let dataFolder = URL(filePath: data, directoryHint: .isDirectory)
        return AppDependencies.Environment(
            dataFolder: dataFolder,
            preferences: store,
            secrets: InMemorySecretStore(),
            inbox: ProcessInfo.processInfo.environment["SWIFTPOLIS_DEBUG_SHARED_INBOX"] != nil
                ? BrowserInbox.shared
                : BrowserInbox(folder: URL(filePath: data + "/Inbox", directoryHint: .isDirectory)),
            helpers: AppDependencies.helpers(in: dataFolder)
        )
    }

    static func run() {
        guard data != nil else { return }
        let environment = ProcessInfo.processInfo.environment
        if let folder = environment["SWIFTPOLIS_DEBUG_SNAPSHOTS"] { startSnapshots(to: folder) }

        Task {
            while AppModel.shared.services == nil, AppModel.shared.openWindowAction == nil {
                try? await Task.sleep(for: .milliseconds(100))
            }
            try? await Task.sleep(for: .seconds(1))
            let model = AppModel.shared
            for id in (environment["SWIFTPOLIS_DEBUG_OPEN"] ?? "").split(separator: ",") {
                model.openWindowAction?(id: String(id))
            }
            if environment["SWIFTPOLIS_DEBUG_DOCK_CHECK"] != nil {
                func report(_ moment: String) {
                    print("\(moment): \(NSApp.activationPolicy() == .regular ? "in Dock" : "menu bar only")", terminator: " ")
                    print("titled windows: \(NSApp.windows.filter { $0.styleMask.contains(.titled) && $0.isVisible }.count)")
                    fflush(stdout)
                }
                try? await Task.sleep(for: .seconds(3))
                report("window open")
                for window in NSApp.windows where window.styleMask.contains(.titled) { window.close() }
                try? await Task.sleep(for: .seconds(2))
                report("no windows")
                model.openWindowAction?(id: WindowID.main)
                NSApp.activate()
                try? await Task.sleep(for: .seconds(2))
                report("reopened")
                for window in NSApp.windows where window.styleMask.contains(.titled) { window.close() }
                try? await Task.sleep(for: .seconds(2))
                report("closed again")
                var preferences = model.preferences
                preferences.keepsDockIconWithoutWindows = true
                model.preferences = preferences
                NSApp.updateWindows()
                try? await Task.sleep(for: .seconds(2))
                report("with the option on")
            }
            if let text = environment["SWIFTPOLIS_DEBUG_PASTE"], let id = environment["SWIFTPOLIS_DEBUG_PASTE_WINDOW"] {
                await paste(text, intoWindow: id)
            }
            if let link = environment["SWIFTPOLIS_DEBUG_VIDEO"] {
                model.showVideoFinder(for: BrowserLink(url: link))
            }
            if let links = environment["SWIFTPOLIS_DEBUG_QUEUE"], let services = model.services {
                for link in links.split(separator: ",") {
                    var draft = DownloadDraft(preferences: model.preferences)
                    draft.link = String(link)
                    draft.category = CategoryKind.scheduledDownloadsName
                    _ = try? await services.coordinator.add(
                        draft.request, secrets: draft.secrets, to: draft.category, startNow: false
                    )
                }
                try? await services.coordinator.startQueue(CategoryKind.scheduledDownloadsName)
            }
            guard let link = environment["SWIFTPOLIS_DEBUG_ADD"], let services = model.services else { return }
            let draft = {
                var draft = DownloadDraft(preferences: model.preferences)
                draft.link = link
                return draft
            }()
            if let gid = try? await services.coordinator.add(
                draft.request, secrets: draft.secrets, to: CategoryKind.singleDownloadsName, startNow: true
            ) {
                model.didStart(gid, isScheduled: false)
            }
        }
    }

    /// Goes through the field editor's own paste, so the field treats the text as it would a real
    /// one, without touching the clipboard.
    private static func paste(_ text: String, intoWindow id: String) async {
        func firstField(in view: NSView) -> NSTextField? {
            if let field = view as? NSTextField, field.isEditable { return field }
            return view.subviews.lazy.compactMap(firstField).first
        }
        let model = AppModel.shared
        model.openWindowAction?(id: id)
        NSApp.activate()
        try? await Task.sleep(for: .seconds(2))
        let titles = { NSApp.windows.filter(\.isVisible).map(\.title).filter { !$0.isEmpty } }
        let window = NSApp.windows.first { $0.identifier?.rawValue.hasPrefix(id) == true }
        guard let window, let content = window.contentView, let field = firstField(in: content) else {
            print("paste: no field in \(titles())")
            fflush(stdout)
            return
        }
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(field)
        let pasteboard = NSPasteboard(name: .init("SwiftpolisDebugPaste"))
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        print("paste: into \(window.title), found patterns:", (try? await pasteboard.detectedPatterns(for: [\.probableWebURL])) ?? [])
        (field.currentEditor() as? NSTextView)?.readSelection(from: pasteboard)
        try? await Task.sleep(for: .seconds(2))
        print("paste: the field holds \(field.stringValue.count) characters, \(field.stringValue.filter(\.isNewline).count) line breaks; windows: \(titles())")
        fflush(stdout)
    }

    private static func startSnapshots(to folder: String) {
        try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        Task {
            while true {
                try? await Task.sleep(for: .seconds(1))
                for window in NSApp.windows where window.isVisible && window.contentView != nil {
                    write(window, to: folder)
                }
            }
        }
    }

    private static func write(_ window: NSWindow, to folder: String) {
        guard let view = window.contentView?.superview ?? window.contentView,
              let image = view.bitmapImageRepForCachingDisplay(in: view.bounds)
        else { return }
        view.cacheDisplay(in: view.bounds, to: image)
        guard let png = image.representation(using: .png, properties: [:]) else { return }
        let name = (window.identifier?.rawValue ?? window.title)
            .replacingOccurrences(of: "/", with: "_")
            .prefix(40)
        try? png.write(to: URL(filePath: "\(folder)/\(name).png"))
        try? describe(view).write(toFile: "\(folder)/\(name).txt", atomically: true, encoding: .utf8)
    }

    /// The view tree as text, for layout problems a picture can't explain.
    private static func describe(_ view: NSView, depth: Int = 0) -> String {
        var text = String(repeating: "  ", count: depth)
            + "\(type(of: view)) \(Int(view.frame.minX)),\(Int(view.frame.minY)) \(Int(view.frame.width))x\(Int(view.frame.height))"
            + (view.isHidden ? " hidden" : "") + "\n"
        for subview in view.subviews where depth < 14 {
            text += describe(subview, depth: depth + 1)
        }
        return text
    }
}
#endif
