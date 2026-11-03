import Foundation
import Observation
import SwiftpolisDomain
import SwiftpolisEngines
import SwiftpolisPersistence
import SwiftpolisServices
import UserNotifications

/// What the whole app shares: the services, live progress and preferences.
///
/// Downloads belong to the system here, so this can start from nothing at any moment and pick up
/// whatever carried on without it. See docs/adr/0010-ios-downloads-belong-to-the-system.md.
@Observable
final class MobileModel {
    struct Services {
        let library: LibraryRepository
        let coordinator: DownloadCoordinator
    }

    enum State {
        case starting
        case ready(Services)
        case failed(message: String)
    }

    static let shared = MobileModel()

    private(set) var state = State.starting
    private(set) var snapshots: [GID: DownloadSnapshot] = [:]
    /// Goes up whenever a saved list changes, so anything showing one knows to reload it.
    private(set) var listRevision = 0
    private(set) var runningQueues: Set<String> = []

    var preferences: Preferences {
        didSet { preferencesStore.preferences = preferences }
    }

    /// Made as early as possible, because iOS expects the session back as soon as the app launches.
    @ObservationIgnored let transfers: BackgroundTransfers
    @ObservationIgnored private let preferencesStore = PreferencesStore()
    @ObservationIgnored private let dataFolder = URL.applicationSupportDirectory
        .appending(path: "Swiftpolis", directoryHint: .isDirectory)
    @ObservationIgnored private var isStarting = false

    private static let lastDocumentsFolderKey = "lastDocumentsFolder"

    private init() {
        // Files go where the Files app can see them, and that place can move between app updates.
        var preferences = preferencesStore.preferences
        preferences.downloadFolder = URL.documentsDirectory.path
        preferencesStore.preferences = preferences
        self.preferences = preferences

        transfers = BackgroundTransfers(
            configuration: BackgroundTransfers.backgroundConfiguration(
                identifier: (Bundle.main.bundleIdentifier ?? "Swiftpolis") + ".downloads"
            ),
            folder: dataFolder.appending(path: "Transfers", directoryHint: .isDirectory)
        )
    }

    var services: Services? {
        if case .ready(let services) = state { return services }
        return nil
    }

    func start() async {
        guard case .starting = state, !isStarting else { return }
        isStarting = true
        do {
            try FileManager.default.createDirectory(at: dataFolder, withIntermediateDirectories: true)
            let container = try LibraryStore.makeContainer(at: dataFolder.appending(path: "Library.store"))
            let library = LibraryRepository(modelContainer: container)
            try await library.prepareForLaunch()
            try await followDocumentsFolder(library)

            let store = preferencesStore
            let transfers = transfers
            let coordinator = DownloadCoordinator(
                library: library,
                secrets: KeychainSecretStore(),
                makeEngine: { gid, request, secrets in
                    BackgroundDownloadEngine(
                        gid: gid,
                        request: request,
                        secrets: secrets,
                        settings: store.preferences.engineSettings,
                        transfers: transfers
                    )
                },
                spider: { request, secrets in
                    await Spider.look(at: request, secrets: secrets, settings: store.preferences.engineSettings)
                },
                handsQueuesToSystem: true,
                discardKept: { transfers.discard($0) }
            )
            state = .ready(Services(library: library, coordinator: coordinator))
            Task { await listen(to: coordinator) }
            await coordinator.adopt(await transfers.unfinishedDownloads())
        } catch {
            state = .failed(message: error.localizedDescription)
        }
    }

    private func followDocumentsFolder(_ library: LibraryRepository) async throws {
        let defaults = UserDefaults.standard
        let current = URL.documentsDirectory.path
        if let last = defaults.string(forKey: Self.lastDocumentsFolderKey), last != current {
            try await library.moveSavedPaths(from: last, to: current)
        }
        defaults.set(current, forKey: Self.lastDocumentsFolderKey)
    }

    private func listen(to coordinator: DownloadCoordinator) async {
        for await event in coordinator.events {
            switch event {
            case .listChanged:
                listRevision += 1
            case .progress(let snapshots):
                self.snapshots = snapshots
            case .finished(let download):
                listRevision += 1
                announce(download)
            case .queuesChanged(let names):
                runningQueues = names
            case .queueFinished(let name, let outcome):
                if outcome == .completed { notify("Queue finished", body: name) }
            case .shuttingDown, .videoPairsChanged, .videoPairFinished:
                break
            }
        }
    }

    private func announce(_ download: FinishedDownload) {
        let name = download.fileName ?? download.link
        switch download.status {
        case .complete: notify("Download Complete", body: name)
        case .error: notify("Download Failed", body: name)
        default: break
        }
    }

    // MARK: Telling the person

    /// Only asked once there's a download to tell them about.
    func askToNotify() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// iOS holds these back while the app is on screen, where the list already says the same.
    func notify(_ title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.threadIdentifier = "downloads"
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
