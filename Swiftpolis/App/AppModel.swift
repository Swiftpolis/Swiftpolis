import AppKit
import Foundation
import Observation
import SwiftUI
import SwiftpolisBridge
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
    static let batchAdd = "batch-add"
    static let videoFinder = "video-finder"
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
    private(set) var runningQueues: Set<String> = []
    /// The Video pairs at work, known by their video stream.
    private(set) var activePairs: Set<GID> = []

    var preferences: Preferences {
        didSet {
            preferencesStore.preferences = preferences
            updateKeepAwake()
        }
    }

    @ObservationIgnored let secrets: any SecretStore
    @ObservationIgnored let helpers: HelperInstallation
    @ObservationIgnored var openWindowAction: OpenWindowAction?

    @ObservationIgnored private let preferencesStore: PreferencesStore
    @ObservationIgnored private let dataFolder: URL
    @ObservationIgnored private let notifier = Notifier()
    @ObservationIgnored private var keepAwakeActivity: NSObjectProtocol?
    @ObservationIgnored private let inbox: BrowserInbox?
    /// Links waiting for a window to open and ask for them. Windows are given a key rather than the
    /// links, so that cookies never become part of a window's saved state.
    @ObservationIgnored private var waitingAddLinks: [String: BrowserLink] = [:]
    @ObservationIgnored private var batchStartedDownloads: Set<GID> = []
    @ObservationIgnored private var waitingBatches: [String: [BrowserLink]] = [:]
    @ObservationIgnored private var waitingVideoLinks: [String: BrowserLink] = [:]

    private init() {
        let environment = AppDependencies.environment()
        preferencesStore = environment.preferences
        preferences = environment.preferences.preferences
        secrets = environment.secrets
        dataFolder = environment.dataFolder
        inbox = environment.inbox
        helpers = environment.helpers
    }

    var services: Services? {
        if case .ready(let services) = state { return services }
        return nil
    }

    var hasActiveDownloads: Bool { !snapshots.isEmpty || !runningQueues.isEmpty || !activePairs.isEmpty }

    func start() async {
        guard case .starting = state else { return }
        do {
            let store = preferencesStore
            let helpers = helpers
            let library = try AppDependencies.makeLibrary(in: dataFolder)
            try await library.prepareForLaunch()
            let coordinator = DownloadCoordinator(
                library: library,
                secrets: secrets,
                queueWait: { store.preferences.queueWait },
                shutDown: { await AppModel.shared.shutDownSystem() },
                makeEngine: { request, secrets in
                    let settings = store.preferences.engineSettings
                    switch request.engine {
                    case .http:
                        return HTTPDownloadEngine(request: request, secrets: secrets, settings: settings)
                    case .ytDlp:
                        return YtDlpEngine(request: request, secrets: secrets, settings: settings, helpers: helpers.paths)
                    }
                },
                spider: { request, secrets in
                    await Spider.look(at: request, secrets: secrets, settings: store.preferences.engineSettings)
                },
                mux: { video, audio, folder in
                    do throws(VideoMuxer.Failure) {
                        return .success(try await VideoMuxer.mux(
                            video: video,
                            audio: audio,
                            folder: VideoMuxer.folder(forDownloadIn: folder, settings: store.preferences.engineSettings),
                            ffmpeg: helpers.paths.ffmpeg
                        ))
                    } catch {
                        return .failure(error)
                    }
                }
            )
            state = .ready(Services(library: library, coordinator: coordinator))
            notifier.requestPermission()
            installBrowserHelpers()
            Task { await listen(to: coordinator) }
            Task { await watchClipboard() }
            Task { await updateHelpers() }
            drainInbox()
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
            case .queuesChanged(let names):
                runningQueues = names
            case .queueFinished(_, let outcome):
                handleQueueFinished(outcome)
            case .shuttingDown:
                notify("Swiftpolis is shutting down", body: "your system in 20 seconds", sound: .warning)
            case .videoPairsChanged(let pairs):
                activePairs = pairs
                updateKeepAwake()
            case .videoPairFinished(let result):
                handlePairFinished(result)
            }
        }
    }

    /// Keeps yt-dlp up to date, in the background. This can take a while, and nothing waits for it.
    private func updateHelpers() async {
        #if DEBUG
        guard !DebugAutomation.isActive || DebugAutomation.updatesHelpers else { return }
        #endif
        let store = preferencesStore
        let helpers = helpers
        let lastCheck = store.lastYtDlpUpdateCheck
        store.lastYtDlpUpdateCheck = await Task.detached {
            await helpers.updateIfDue(lastCheck: lastCheck)
        }.value
    }

    // MARK: Links from elsewhere

    private func installBrowserHelpers() {
        #if DEBUG
        // A Debug build's helper lives in a build folder that comes and goes, and pointing browsers
        // at it would take them away from whatever they use now, so this has to be asked for.
        guard ProcessInfo.processInfo.environment["SWIFTPOLIS_INSTALL_BROWSER_HELPERS"] != nil else { return }
        #endif
        let helper = Bundle.main.bundleURL.appending(path: "Contents/MacOS/swiftpolis-native-host")
        NativeHostManifests.install(
            helperPath: helper.path,
            home: FileManager.default.homeDirectoryForCurrentUser
        )
    }

    /// Picks up what browsers have left. Does nothing until there's a window action to show them
    /// with, and is called again when there is.
    func drainInbox() {
        guard services != nil, openWindowAction != nil, let inbox else { return }
        for links in inbox.drain() {
            handle(links)
        }
    }

    private func handle(_ links: [BrowserLink]) {
        let plan = BrowserRequestPlan(
            links: links,
            startsImmediately: preferences.startsBrowserRequestsImmediately,
            videoFinderMaxLinks: preferences.videoFinderMaxLinks
        )
        for link in plan.videoFinder {
            showVideoFinder(for: link)
        }
        switch plan.route {
        case .addLink(let link):
            showAddLink(for: link)
        case .startNow(let link):
            startNow(link)
        case .batch(let links):
            showBatch(for: links)
        case nil:
            break
        }
    }

    func showAddLink(for link: BrowserLink) {
        let key = UUID().uuidString
        waitingAddLinks[key] = link
        openWindowAction?(id: WindowID.addLink, value: key)
        NSApp.activate()
    }

    func showBatch(for links: [BrowserLink]) {
        let key = UUID().uuidString
        waitingBatches[key] = links
        openWindowAction?(id: WindowID.batchAdd, value: key)
        NSApp.activate()
    }

    func showVideoFinder(for link: BrowserLink) {
        let key = UUID().uuidString
        waitingVideoLinks[key] = link
        openWindowAction?(id: WindowID.videoFinder, value: key)
        NSApp.activate()
    }

    func waitingVideoLink(_ key: String) -> BrowserLink? { waitingVideoLinks[key] }

    func waitingAddLink(_ key: String) -> BrowserLink? { waitingAddLinks[key] }
    func waitingBatch(_ key: String) -> [BrowserLink]? { waitingBatches[key] }

    func forgetWaitingLinks(_ key: String) {
        waitingAddLinks[key] = nil
        waitingBatches[key] = nil
        waitingVideoLinks[key] = nil
    }

    private func startNow(_ link: BrowserLink) {
        guard let coordinator = services?.coordinator else { return }
        let draft = DownloadDraft(preferences: preferences, browserLink: link)
        Task {
            do {
                let gid = try await coordinator.add(
                    draft.request,
                    secrets: draft.secrets,
                    to: CategoryKind.singleDownloadsName,
                    startNow: true
                )
                didStart(gid, isScheduled: false)
            } catch {
                notify("Operation was not successful.", body: error.localizedDescription, sound: .fail)
            }
        }
    }

    /// Opens the right window for some links, typed or read from a file or the clipboard.
    func showWindow(forLinksIn text: String) {
        let links = LinkText.links(in: text).map { BrowserLink(url: $0) }
        switch links.count {
        case 0: break
        case 1:
            if VideoSites.isSupported(links[0].url) {
                showVideoFinder(for: links[0])
            } else {
                showAddLink(for: links[0])
            }
        default: showBatch(for: links)
        }
    }

    /// Opens the batch window if a Link field was given a whole list, such as a season's episodes.
    /// Returns whether it did, so the field's window can make way for it.
    func showBatch(forListIn text: String) -> Bool {
        let links = LinkText.links(in: text)
        guard links.count > 1 else { return false }
        showBatch(for: links.map { BrowserLink(url: $0) })
        return true
    }

    /// Persepolis's clipboard monitoring, which never fired there (D5). The pasteboard's change count
    /// needs no permission. Looking for a link pattern before reading means the clipboard is only
    /// read, and macOS only asks, when there's a link to act on.
    private func watchClipboard() async {
        #if DEBUG
        if DebugAutomation.isActive { return }
        #endif
        let pasteboard = NSPasteboard.general
        var lastChange = pasteboard.changeCount
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            guard pasteboard.changeCount != lastChange else { continue }
            lastChange = pasteboard.changeCount
            guard preferences.checksClipboard else { continue }

            let patterns = try? await pasteboard.detectedPatterns(for: [\.probableWebURL])
            if patterns?.contains(\.probableWebURL) == true, let text = pasteboard.string(forType: .string) {
                showWindow(forLinksIn: text)
            }
        }
    }

    // MARK: Starting and finishing

    /// Marks a Single Download started with others, so a season doesn't end in a window per episode.
    func markBatchStarted(_ gid: GID) {
        batchStartedDownloads.insert(gid)
    }

    /// Shows a just-started Download's progress window and says it has started.
    func didStart(_ gid: GID, isScheduled: Bool) {
        notify(isScheduled ? "Download Scheduled" : "Download Starts", sound: nil)
        showProgressWindow(gid)
    }

    func showProgressWindow(_ gid: GID) {
        guard preferences.showsProgressWindow else { return }
        openWindowAction?(id: WindowID.progress, value: gid.rawValue)
    }

    /// Announces a finish. A Queue reports on itself, so this is for Single Downloads only.
    private func handleFinished(_ download: FinishedDownload) {
        guard CategoryKind(categoryName: download.category) == .singleDownloads else { return }
        // A finished stream isn't the file yet. Its pair announces that.
        if download.isVideoPairStream, download.status == .complete { return }
        let name = download.fileName ?? download.link
        switch download.status {
        case .complete:
            notify("Download Complete", body: name, sound: .ok)
            let wasBatchStarted = batchStartedDownloads.remove(download.gid) != nil
            if preferences.showsAfterDownloadDialog, !wasBatchStarted {
                openWindowAction?(id: WindowID.afterDownload, value: download.gid.rawValue)
                NSApp.activate()
            }
        case .stopped:
            notify(download.errorMessage ?? "Download Stopped", body: name, sound: nil)
        case .error:
            let message = download.errorMessage ?? "Error"
            notify("Error - \(message)", body: name, sound: .fail)
        default:
            break
        }
    }

    private func handlePairFinished(_ result: VideoPairResult) {
        switch result.outcome {
        case .complete(let fileName, _):
            // As with any Download, a Queue reports on itself.
            guard CategoryKind(categoryName: result.category) == .singleDownloads else { return }
            notify("Download Complete", body: fileName, sound: .ok)
            if preferences.showsAfterDownloadDialog {
                openWindowAction?(id: WindowID.afterDownload, value: result.videoGID.rawValue)
                NSApp.activate()
            }
        case .notEnoughSpace(let folder):
            notify("Not enough free space in:", body: folder, sound: .fail)
        case .muxingFailed:
            notify("an error occurred", body: "muxing error", sound: .fail)
        }
    }

    private func handleQueueFinished(_ outcome: QueueOutcome) {
        switch outcome {
        case .completed:
            notify("Swiftpolis", body: "Queue completed!", sound: .queue)
        case .stoppedByUser:
            notify("Swiftpolis", body: "Queue Stopped!", sound: nil)
        case .stoppedBySchedule(let message):
            notify("Swiftpolis", body: message ?? "Queue Stopped!", sound: nil)
        }
    }

    /// Only reached once a requested shutdown has stopped everything.
    func shutDownSystem() {
        #if DEBUG
        // Automated runs must never really turn off the Mac they run on.
        if DebugAutomation.isActive {
            print("Would shut down now")
            return
        }
        #endif
        if let message = SystemShutdown.perform() {
            notify("Couldn't shut down", body: message, sound: .fail)
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
