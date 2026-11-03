import AppKit
import Foundation
import Observation
import SwiftUI
import SwiftpolisDomain
import SwiftpolisEngines
import SwiftpolisPersistence
import SwiftpolisServices

enum WindowID {
    static let main = "main"
    static let addLink = "add-link"
    static let progress = "progress"
    static let properties = "properties"
    static let afterDownload = "after-download"
}

/// What the whole app shares: the services, live progress and preferences.
///
/// It also handles what happens when a Download starts or finishes, because that has to work with
/// any set of windows open, or none.
@Observable
final class AppModel {
    struct Services {
        let library: LibraryRepository
        let coordinator: DownloadCoordinator
    }

    enum State {
        case starting
        case ready(Services)
        case failed(message: String)
    }

    static let shared = AppModel()

    private(set) var state = State.starting
    private(set) var snapshots: [GID: DownloadSnapshot] = [:]
    /// Goes up whenever a saved list changes, so anything showing one knows to reload it.
    private(set) var listRevision = 0

    var preferences: Preferences {
        didSet {
            preferencesStore.preferences = preferences
            updateKeepAwake()
        }
    }

    @ObservationIgnored let secrets: any SecretStore
    @ObservationIgnored var openWindowAction: OpenWindowAction?

    @ObservationIgnored private let preferencesStore: PreferencesStore
    @ObservationIgnored private let dataFolder: URL
    @ObservationIgnored private let notifier = Notifier()
    @ObservationIgnored private var keepAwakeActivity: NSObjectProtocol?

    private init() {
        let environment = AppDependencies.environment()
        preferencesStore = environment.preferences
        preferences = environment.preferences.preferences
        secrets = environment.secrets
        dataFolder = environment.dataFolder
    }

    var services: Services? {
        if case .ready(let services) = state { return services }
        return nil
    }

    var hasActiveDownloads: Bool { !snapshots.isEmpty }

    func start() async {
        guard case .starting = state else { return }
        do {
            let store = preferencesStore
            let library = try AppDependencies.makeLibrary(in: dataFolder)
            try await library.prepareForLaunch()
            let coordinator = DownloadCoordinator(
                library: library,
                secrets: secrets,
                makeEngine: { request, secrets in
                    HTTPDownloadEngine(request: request, secrets: secrets, settings: store.preferences.engineSettings)
                },
                spider: { request, secrets in
                    await Spider.look(at: request, secrets: secrets, settings: store.preferences.engineSettings)
                }
            )
            state = .ready(Services(library: library, coordinator: coordinator))
            notifier.requestPermission()
            Task { await listen(to: coordinator) }
        } catch {
            state = .failed(message: error.localizedDescription)
        }
    }

    private func listen(to coordinator: DownloadCoordinator) async {
        for await event in coordinator.events {
            switch event {
            case .listChanged:
                listRevision += 1
            case .progress(let snapshots):
                self.snapshots = snapshots
                updateKeepAwake()
            case .finished(let download):
                listRevision += 1
                handleFinished(download)
            }
        }
    }

    // MARK: Starting and finishing

    /// Shows a just-started Download's progress window and says it has started.
    func didStart(_ gid: GID) {
        notify("Download Starts", sound: nil)
        showProgressWindow(gid)
    }

    func showProgressWindow(_ gid: GID) {
        guard preferences.showsProgressWindow else { return }
        openWindowAction?(id: WindowID.progress, value: gid.rawValue)
    }

    /// Announces a finish. A Queue reports on itself, so this is for Single Downloads only.
    private func handleFinished(_ download: FinishedDownload) {
        guard CategoryKind(categoryName: download.category) == .singleDownloads else { return }
        let name = download.fileName ?? download.link
        switch download.status {
        case .complete:
            notify("Download Complete", body: name, sound: .ok)
            if preferences.showsAfterDownloadDialog {
                openWindowAction?(id: WindowID.afterDownload, value: download.gid.rawValue)
                NSApp.activate()
            }
        case .stopped:
            notify("Download Stopped", body: name, sound: nil)
        case .error:
            let message = download.errorMessage ?? "Error"
            notify("Error - \(message)", body: name, sound: .fail)
        default:
            break
        }
    }

    func notify(_ title: String, body: String = "", sound: Notifier.Sound?) {
        notifier.send(
            title: title,
            body: body,
            sound: sound,
            playsSounds: preferences.playsSounds,
            volumePercent: preferences.soundVolumePercent
        )
    }

    // MARK: Keep awake

    private func updateKeepAwake() {
        let shouldHold = preferences.keepsSystemAwake && hasActiveDownloads
        if shouldHold, keepAwakeActivity == nil {
            keepAwakeActivity = ProcessInfo.processInfo.beginActivity(
                options: [.idleSystemSleepDisabled, .userInitiated],
                reason: "Downloading files"
            )
        } else if !shouldHold, let activity = keepAwakeActivity {
            ProcessInfo.processInfo.endActivity(activity)
            keepAwakeActivity = nil
        }
    }
}
