import AppKit
import Foundation
import Observation
import SwiftpolisDomain
import SwiftpolisEngines
import SwiftpolisServices
import SwiftpolisPersistence
import SwiftUI

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
    var selectedCategoryName = CategoryKind.allDownloadsName
    var selection: Set<GID> = []

    private let model: AppModel
    private let unknown = "***"
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd , HH:mm:ss"
        return formatter
    }()

    init(model: AppModel) {
        self.model = model
    }

    private var services: AppModel.Services? { model.services }

    func reload() async {
        guard let library = services?.library else { return }
        do {
            categories = try await library.categories()
            downloads = try await library.downloads(in: selectedCategoryName)
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
            connections: live.map { String($0.activeConnections) } ?? unknown,
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
        return DownloadActions(status: status, category: download.category)
    }

    // MARK: Control

    func resume() {
        guard let gid = selectedDownload?.gid else { return }
        control("resume") { [self] coordinator in
            try await coordinator.resume(gid)
            model.showProgressWindow(gid)
        }
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
            }
        }
    }

    func clearList() {
        guard let coordinator = services?.coordinator else { return }
        Task {
            do {
                try await coordinator.clearList()
                selectedCategoryName = CategoryKind.allDownloadsName
            } catch {
                model.notify("Stop all downloads first!", sound: .fail)
            }
        }
    }

    func sort(by key: DownloadSortKey) {
        guard let coordinator = services?.coordinator else { return }
        let category = selectedCategoryName
        Task { try? await coordinator.sort(category, by: key) }
    }
}
