#if DEBUG
import AppKit
import Foundation
import SwiftUI
import SwiftpolisDomain
import SwiftpolisServices

/// Lets a Debug build be checked without anyone at the keyboard. Release builds don't contain this.
///
/// - `SWIFTPOLIS_DEBUG_DATA`: a folder to keep all data in, instead of the real library, preferences
///   and Keychain. Nothing else here runs without it.
/// - `SWIFTPOLIS_DEBUG_SNAPSHOTS`: a folder to write each window to, as PNGs, once a second.
/// - `SWIFTPOLIS_DEBUG_ADD`: a link to add and start once the app is ready.
/// - `SWIFTPOLIS_DEBUG_OPEN`: window IDs to open, separated by commas.
/// - `SWIFTPOLIS_DEBUG_QUEUE`: links to add to Scheduled Downloads, separated by commas, before starting
///   it and showing it in the main window.
enum DebugAutomation {
    private static var data: String? { ProcessInfo.processInfo.environment["SWIFTPOLIS_DEBUG_DATA"] }

    static var isActive: Bool { data != nil }

    /// The Category the main window should open on.
    static var initialCategory: String? {
        guard isActive, ProcessInfo.processInfo.environment["SWIFTPOLIS_DEBUG_QUEUE"] != nil else { return nil }
        return CategoryKind.scheduledDownloadsName
    }

    nonisolated static func environment() -> AppDependencies.Environment? {
        guard let data = ProcessInfo.processInfo.environment["SWIFTPOLIS_DEBUG_DATA"] else { return nil }
        let defaults = UserDefaults(suiteName: "SwiftpolisDebug-\(abs(data.hashValue))") ?? .standard
        let store = PreferencesStore(defaults: defaults)
        var preferences = Preferences()
        preferences.downloadFolder = data + "/Downloads"
        store.preferences = preferences
        return AppDependencies.Environment(
            dataFolder: URL(filePath: data, directoryHint: .isDirectory),
            preferences: store,
            secrets: InMemorySecretStore()
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
