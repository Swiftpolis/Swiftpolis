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
enum DebugAutomation {
    private static var data: String? { ProcessInfo.processInfo.environment["SWIFTPOLIS_DEBUG_DATA"] }

    static var isActive: Bool { data != nil }

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
            guard let link = environment["SWIFTPOLIS_DEBUG_ADD"], let services = model.services else { return }
            let draft = {
                var draft = DownloadDraft(preferences: model.preferences)
                draft.link = link
                return draft
            }()
            if let gid = try? await services.coordinator.add(
                draft.request, secrets: draft.secrets, to: CategoryKind.singleDownloadsName, startNow: true
            ) {
                model.didStart(gid)
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
    }
}
#endif
