import AppKit
import Foundation
import Observation
import SwiftpolisBridge
import SwiftpolisDomain
import SwiftpolisEngines
import SwiftpolisServices
import SwiftpolisPersistence
import SwiftUI

/// What the side panel shows about a Video pair.
struct VideoPairStatus {
    let activity: String
    let muxing: String
    let video: String
    let audio: String
    let canMux: Bool
}

/// One line of the main table, as display text.
struct DownloadRow: Identifiable, Hashable {
    let id: GID
    let name: String
    let status: String
    let size: String
    let downloaded: String
    let percent: String
    let connections: String
    let rate: String
    let timeLeft: String
    let firstTry: String
    let lastTry: String
    let category: String
}

@Observable
final class MainWindowViewModel {
    private(set) var categories: [CategorySummary] = []
    private(set) var downloads: [DownloadSummary] = []
    private(set) var pairs: [VideoPair] = []
    var selectedCategoryName = CategoryKind.allDownloadsName
    var selection: Set<GID> = []

    /// Each Queue's panel settings while it runs, which last only as long as the run.
    private var queueDials: [String: Double] = [:]
    private var queueShutdowns: Set<String> = []

    private let model: AppModel
    private let unknown = "***"
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd , HH:mm:ss"
        return formatter
    }()

    init(model: AppModel) {
        self.model = model
        #if DEBUG
        if let category = DebugAutomation.initialCategory { selectedCategoryName = category }
        #endif
    }

    private var services: AppModel.Services? { model.services }

    func reload() async {
        guard let library = services?.library else { return }
        do {
            categories = try await library.categories()
            downloads = try await library.downloads(in: selectedCategoryName)
            pairs = try await library.videoPairs()
            selection.formIntersection(downloads.map(\.gid))
        } catch {
            model.notify("Can't read your downloads", body: error.localizedDescription, sound: .fail)
        }
    }

    // MARK: What's shown

    var rows: [DownloadRow] { downloads.map(row(for:)) }

    private func row(for download: DownloadSummary) -> DownloadRow {
        let live = model.snapshots[download.gid]
        let total = live?.totalBytes ?? download.totalBytes
        let downloaded = live?.downloadedBytes ?? download.downloadedBytes
        let status = live?.status ?? download.status
        let percent = live?.percent ?? percentage(downloaded, of: total, status: status)
        return DownloadRow(
            id: download.gid,
            name: live?.fileName ?? download.fileName ?? unknown,
            status: status.rawValue,
            size: total.map(ByteFormat.size) ?? unknown,
            downloaded: downloaded > 0 ? ByteFormat.size(downloaded) : unknown,
            percent: percent.map { "\($0)%" } ?? unknown,
            connections: live.map { $0.fragments ?? String($0.activeConnections) } ?? unknown,
            rate: live.map { ByteFormat.speed($0.bytesPerSecond) } ?? unknown,
            timeLeft: live?.secondsRemaining.map(DurationFormat.remaining(seconds:)) ?? unknown,
            firstTry: Self.dateFormatter.string(from: download.firstTryDate),
            lastTry: Self.dateFormatter.string(from: download.lastTryDate),
            category: download.category
        )
    }

    private func percentage(_ downloaded: Int64, of total: Int64?, status: DownloadStatus) -> Int? {
        if status == .complete { return 100 }
        guard let total, total > 0 else { return nil }
        return Int(downloaded * 100 / total)
    }

    /// The Download the toolbar acts on: the first selected, as in Persepolis.
    private var selectedDownload: DownloadSummary? {
        downloads.first { selection.contains($0.gid) }
    }

    var selectedLink: String? { selectedDownload?.request.link }
    var hasSelection: Bool { !selection.isEmpty }

    var actions: DownloadActions {
        guard let download = selectedDownload else { return DownloadActions() }
        let status = model.snapshots[download.gid]?.status ?? download.status
        return DownloadActions(status: status, category: download.category, engine: download.request.engine)
    }

    // MARK: Video pairs

    private var selectedPair: VideoPair? {
        selectedDownload.flatMap { download in pairs.first { $0.contains(download.gid) } }
    }

    /// What the side panel says about the selected Video pair. `nil` if one isn't selected.
    var selectedPairStatus: VideoPairStatus? {
        guard let pair = selectedPair else { return nil }
        let isActive = model.activePairs.contains(pair.videoGID)
        let isVideoComplete = status(of: pair.videoGID) == .complete
        let isAudioComplete = status(of: pair.audioGID) == .complete

        let muxing: String
        switch pair.muxingStatus {
        case .notStarted: muxing = "Not Active"
        case .muxing: muxing = "Started"
        case .error: muxing = "Error"
        case .complete: muxing = "Complete"
        }
        return VideoPairStatus(
            activity: isActive ? "Active" : "Not Active",
            muxing: muxing,
            video: streamText(pair.videoGID),
            audio: streamText(pair.audioGID),
            canMux: isVideoComplete && isAudioComplete && !isActive
        )
    }

    private func status(of gid: GID) -> DownloadStatus? {
        model.snapshots[gid]?.status ?? downloads.first { $0.gid == gid }?.status
    }

    private func streamText(_ gid: GID) -> String {
        if status(of: gid) == .complete { return "Completed" }
        let download = downloads.first { $0.gid == gid }
        let live = model.snapshots[gid]
        let percent = live?.percent ?? download.flatMap {
            percentage($0.downloadedBytes, of: $0.totalBytes, status: $0.status)
        } ?? 0
        return "\(percent)% downloaded"
    }

    func muxSelectedPair() {
        guard let gid = selectedDownload?.gid else { return }
        control("mux") { try await $0.muxAgain(gid) }
    }

    // MARK: Control

    func resume() {
        guard let gid = selectedDownload?.gid else { return }
        control("resume") { [self] coordinator in
            try await coordinator.resume(gid)
            if await !isQueued(gid) { model.showProgressWindow(gid) }
        }
    }

    private func isQueued(_ gid: GID) async -> Bool {
        let category = try? await services?.library.download(gid)?.category
        return category.flatMap { $0 }.map { CategoryKind(categoryName: $0) == .queue } ?? false
    }

    func pause() {
        guard let gid = selectedDownload?.gid else { return }
        control("pause") { try await $0.pause(gid) }
    }

    func stop() {
        guard let gid = selectedDownload?.gid else { return }
        control("stop") { try await $0.stop(gid) }
    }

    private func control(_ verb: String, action: @escaping (DownloadCoordinator) async throws -> Void) {
        guard let coordinator = services?.coordinator else { return }
        Task {
            do {
                try await action(coordinator)
            } catch DownloadControlError.managedByQueue(let queue) {
                model.notify(
                    "Operation was not successful.",
                    body: "Please \(verb) the following category: \(queue)",
                    sound: .fail
                )
            } catch DownloadControlError.stillClosing {
                model.notify("Please retry in a minute!", body: "be patient!", sound: .warning)
            } catch DownloadControlError.pairInProgress {
                model.notify("Download is in progress by video finder!", body: "be patient!", sound: .warning)
            } catch {
                model.notify("Operation was not successful.", body: error.localizedDescription, sound: .fail)
            }
        }
    }

    func stopAll() {
        Task { await services?.coordinator.stopAll() }
    }

    // MARK: Windows and files

    func showProgress() {
        if let gid = selectedDownload?.gid { model.openWindowAction?(id: WindowID.progress, value: gid.rawValue) }
    }

    func showProperties() {
        if let gid = selectedDownload?.gid { model.openWindowAction?(id: WindowID.properties, value: gid.rawValue) }
    }

    func openFile() {
        guard let download = selectedDownload, download.status == .complete, let path = existingPath(download) else { return }
        NSWorkspace.shared.open(URL(filePath: path))
    }

    func openFolder() {
        guard let download = selectedDownload, download.status == .complete, let path = existingPath(download) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(filePath: path)])
    }

    func openDefaultFolder() {
        let folder = URL(filePath: model.preferences.downloadFolder, directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(folder)
    }

    private func existingPath(_ download: DownloadSummary) -> String? {
        guard let path = download.filePath, FileManager.default.fileExists(atPath: path) else {
            model.notify(download.filePath ?? download.fileName ?? download.request.link, body: "Not Found", sound: .warning)
            return nil
        }
        return path
    }

    // MARK: Changing the list

    func removeSelected(deletingFiles: Bool) {
        guard let coordinator = services?.coordinator else { return }
        let gids = Array(selection)
        Task {
            do {
                report(try await coordinator.remove(gids, deletingFiles: deletingFiles))
            } catch {
                model.notify("Operation was not successful!", body: error.localizedDescription, sound: .fail)
            }
        }
    }

    func moveSelectedFiles(to folder: URL) {
        guard let coordinator = services?.coordinator else { return }
        let gids = Array(selection)
        Task {
            do {
                let refusals = try await coordinator.moveFiles(gids, to: folder.path)
                report(refusals)
                if refusals.isEmpty { model.notify("Moving is finished!", sound: .warning) }
            } catch {
                model.notify("Operation was not successful!", body: error.localizedDescription, sound: .fail)
            }
        }
    }

    private func report(_ refusals: [DownloadRefusal]) {
        for refusal in refusals {
            switch refusal {
            case .notStopped(let name):
                model.notify("Operation was not successful!", body: "Please stop the following download first: \(name)", sound: .fail)
            case .fileNotFound(let name):
                model.notify(name, body: "Not Found", sound: .fail)
            case .notComplete(let name):
                model.notify("Operation was not successful!", body: "Following download is not complete: \(name)", sound: .fail)
            case .moveFailed(let name):
                model.notify(name, body: "Operation was not successful!", sound: .fail)
            case .queueRunning(let queue):
                model.notify("Operation was not successful!", body: "Please stop the following category first: \(queue)", sound: .fail)
            case .pairInProgress:
                model.notify("Download is in progress by video finder!", body: "be patient!", sound: .warning)
            }
        }
    }

    func clearList() {
        guard let coordinator = services?.coordinator else { return }
        Task {
            do {
                try await coordinator.clearList()
                queueDials = [:]
                queueShutdowns = []
                selectedCategoryName = CategoryKind.allDownloadsName
            } catch {
                model.notify("Stop all downloads first!", sound: .fail)
            }
        }
    }

    // MARK: Queues

    var selectedCategory: CategorySummary? {
        categories.first { $0.name == selectedCategoryName }
    }

    var isQueueSelected: Bool { selectedCategory?.kind == .queue }
    var isSelectedQueueRunning: Bool { model.runningQueues.contains(selectedCategoryName) }

    /// The categories Downloads can be moved to from the selected one.
    var moveTargets: [String] {
        categories.map(\.name).filter {
            CategoryKind(categoryName: $0) != .allDownloads && $0 != selectedCategoryName
        }
    }

    func updateSelectedQueueOptions(_ options: QueueOptions) {
        guard let coordinator = services?.coordinator else { return }
        let name = selectedCategoryName
        Task { try? await coordinator.updateQueueOptions(options, named: name) }
    }

    func startSelectedQueue() {
        guard let coordinator = services?.coordinator else { return }
        let name = selectedCategoryName
        queueDials[name] = nil
        queueShutdowns.remove(name)
        Task { try? await coordinator.startQueue(name) }
    }

    func stopSelectedQueue() {
        guard let coordinator = services?.coordinator else { return }
        let name = selectedCategoryName
        Task { await coordinator.stopQueue(name) }
    }

    var selectedQueueDial: Double {
        get { queueDials[selectedCategoryName] ?? Double(SpeedDialLabel.maximum) }
        set {
            queueDials[selectedCategoryName] = newValue
            let name = selectedCategoryName
            let dial = Int(newValue)
            Task { await services?.coordinator.setSpeedDial(dial, queue: name) }
        }
    }

    var selectedQueueShutsDown: Bool {
        get { queueShutdowns.contains(selectedCategoryName) }
        set {
            let name = selectedCategoryName
            if newValue { queueShutdowns.insert(name) } else { queueShutdowns.remove(name) }
            Task { await services?.coordinator.setShutdownAfterQueue(newValue, queue: name) }
        }
    }

    func createQueue(named name: String) {
        guard let coordinator = services?.coordinator else { return }
        Task {
            do {
                try await coordinator.createQueue(named: name)
                selectedCategoryName = name
            } catch {
                model.notify("Error!", body: QueueNaming.message(for: error, name: name), sound: .fail)
            }
        }
    }

    var canRemoveSelectedQueue: Bool {
        isQueueSelected && CategoryKind.canRemove(categoryNamed: selectedCategoryName) && !isSelectedQueueRunning
    }

    func removeSelectedQueue() {
        guard let coordinator = services?.coordinator else { return }
        let name = selectedCategoryName
        Task {
            do {
                try await coordinator.removeQueue(named: name)
                selectedCategoryName = CategoryKind.allDownloadsName
            } catch {
                model.notify("Operation was not successful!", body: error.localizedDescription, sound: .fail)
            }
        }
    }

    var canMoveSelection: Bool { isQueueSelected && !isSelectedQueueRunning && hasSelection }

    func moveSelection(_ direction: MoveDirection) {
        guard let coordinator = services?.coordinator else { return }
        let gids = Array(selection)
        let name = selectedCategoryName
        Task { try? await coordinator.moveInQueue(gids, queue: name, direction: direction) }
    }

    func moveSelection(toCategory category: String) {
        guard let coordinator = services?.coordinator else { return }
        let gids = Array(selection)
        Task {
            do {
                report(try await coordinator.moveToCategory(gids, category: category))
            } catch {
                model.notify("Operation was not successful!", body: error.localizedDescription, sound: .fail)
            }
        }
    }

    // MARK: Adding links

    /// Returns whether the drop held any links.
    func addDropped(_ text: String) -> Bool {
        guard !LinkText.links(in: text).isEmpty else { return false }
        model.showWindow(forLinksIn: text)
        return true
    }

    func importLinks(from file: URL) {
        guard let text = try? String(contentsOf: file, encoding: .utf8) else {
            model.notify("Operation was not successful.", body: file.lastPathComponent, sound: .fail)
            return
        }
        model.showWindow(forLinksIn: text)
    }

    func importLinksFromClipboard() {
        model.showWindow(forLinksIn: NSPasteboard.general.string(forType: .string) ?? "")
    }

    func sort(by key: DownloadSortKey) {
        guard let coordinator = services?.coordinator else { return }
        let category = selectedCategoryName
        Task { try? await coordinator.sort(category, by: key) }
    }
}
