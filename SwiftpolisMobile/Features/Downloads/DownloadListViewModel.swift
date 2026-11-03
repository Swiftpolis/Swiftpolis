import Foundation
import Observation
import SwiftpolisDomain
import SwiftpolisEngines
import SwiftpolisPersistence
import SwiftpolisServices

/// One line of the list, as display text.
struct DownloadItem: Identifiable, Hashable {
    let id: GID
    let name: String
    let status: DownloadStatus
    let detail: String
    /// Between 0 and 1, if the size is known and it's worth a bar.
    let fraction: Double?
    let link: String
    let fileURL: URL?
    let canResume: Bool
    let canPause: Bool
    let canStop: Bool
}

@Observable
final class DownloadListViewModel {
    private(set) var categories: [CategorySummary] = []
    private var downloads: [DownloadSummary] = []
    var selectedCategoryName: String? = CategoryKind.allDownloadsName
    var selection: Set<GID> = []
    private(set) var errorMessage: String?

    let model: MobileModel

    init(model: MobileModel) {
        self.model = model
    }

    private var services: MobileModel.Services? { model.services }
    var categoryName: String { selectedCategoryName ?? CategoryKind.allDownloadsName }

    func reload() async {
        guard let library = services?.library else { return }
        do {
            categories = try await library.categories()
            if !categories.contains(where: { $0.name == categoryName }) {
                selectedCategoryName = CategoryKind.allDownloadsName
            }
            downloads = try await library.downloads(in: categoryName)
            selection.formIntersection(downloads.map(\.gid))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearError() {
        errorMessage = nil
    }

    // MARK: What's shown

    var items: [DownloadItem] { downloads.map(item(for:)) }

    private func item(for download: DownloadSummary) -> DownloadItem {
        let live = model.snapshots[download.gid]
        let status = live?.status ?? download.status
        let total = live?.totalBytes ?? download.totalBytes
        let downloaded = live?.downloadedBytes ?? download.downloadedBytes
        let actions = DownloadActions(status: status, category: download.category)
        let isSingle = CategoryKind(categoryName: download.category) == .singleDownloads
        let path = live?.filePath ?? download.filePath

        var fraction: Double?
        if status != .complete, let total, total > 0 {
            fraction = min(1, Double(downloaded) / Double(total))
        }
        return DownloadItem(
            id: download.gid,
            name: live?.fileName ?? download.fileName ?? Spider.fileName(inLink: download.request.link),
            status: status,
            detail: detail(status: status, total: total, downloaded: downloaded, live: live),
            fraction: fraction,
            link: download.request.link,
            fileURL: status == .complete ? path.map { URL(filePath: $0) } : nil,
            canResume: isSingle && actions.canResume,
            canPause: isSingle && actions.canPause,
            canStop: isSingle && actions.canStop
        )
    }

    private func detail(status: DownloadStatus, total: Int64?, downloaded: Int64, live: DownloadSnapshot?) -> String {
        switch status {
        case .complete:
            return total.map(ByteFormat.size) ?? "Finished"
        case .error:
            return live?.errorMessage ?? "Failed. You can try it again."
        case .waiting, .creatingDownloadFile:
            return "Waiting"
        case .scheduled:
            return "Scheduled"
        case .paused, .stopped:
            let word = status == .paused ? "Paused" : "Stopped"
            return downloaded > 0 ? "\(word) at \(ByteFormat.size(downloaded))" : word
        case .downloading:
            // The system has it, but runs only a few at a time.
            if downloaded == 0 { return "Waiting" }
            var parts: [String] = []
            if let total {
                parts.append("\(ByteFormat.size(downloaded)) of \(ByteFormat.size(total))")
            } else {
                parts.append(ByteFormat.size(downloaded))
            }
            if let live, live.bytesPerSecond > 0 { parts.append(ByteFormat.speed(live.bytesPerSecond)) }
            if let seconds = live?.secondsRemaining { parts.append(DurationFormat.remaining(seconds: seconds)) }
            return parts.joined(separator: " · ")
        }
    }

    /// For the top of the list: how far along this list is, and how fast it's going.
    var summary: String? {
        let items = items
        guard !items.isEmpty else { return nil }
        let finished = items.filter { $0.status == .complete }.count
        let speed = downloads.compactMap { model.snapshots[$0.gid]?.bytesPerSecond }.reduce(0, +)
        let progress = "\(finished) of \(items.count) finished"
        return speed > 0 ? "\(progress) · \(ByteFormat.speed(speed))" : progress
    }

    // MARK: Single Downloads

    func resume(_ gids: Set<GID>) {
        control { coordinator in
            for gid in gids { try await coordinator.resume(gid) }
        }
    }

    func pause(_ gid: GID) {
        control { try await $0.pause(gid) }
    }

    func stop(_ gid: GID) {
        control { try await $0.stop(gid) }
    }

    func stopAll() {
        control { await $0.stopAll() }
    }

    func remove(_ gids: Set<GID>, deletingFiles: Bool) {
        control { coordinator in
            let refusals = try await coordinator.remove(Array(gids), deletingFiles: deletingFiles)
            if !refusals.isEmpty { self.errorMessage = "Stop these downloads before removing them." }
        }
    }

    private func control(_ action: @escaping (DownloadCoordinator) async throws -> Void) {
        guard let coordinator = services?.coordinator else { return }
        Task {
            do {
                try await action(coordinator)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: Queues

    var selectedQueue: CategorySummary? {
        categories.first { $0.name == categoryName && $0.kind == .queue }
    }

    var isSelectedQueueRunning: Bool { model.runningQueues.contains(categoryName) }

    func startSelectedQueue() {
        let name = categoryName
        model.askToNotify()
        control { try await $0.startQueue(name) }
    }

    func stopSelectedQueue() {
        let name = categoryName
        control { await $0.stopQueue(name) }
    }

    func createQueue(named name: String) {
        control { coordinator in
            try await coordinator.createQueue(named: name)
            self.selectedCategoryName = name
        }
    }

    func removeQueue(named name: String) {
        control { try await $0.removeQueue(named: name) }
    }

    func saveOptions(_ options: QueueOptions, forQueue name: String) {
        control { try await $0.updateQueueOptions(options, named: name) }
    }

    var canRemoveQueues: Bool { model.runningQueues.isEmpty }
    func isUserQueue(_ category: CategorySummary) -> Bool {
        category.kind == .queue && !CategoryKind.builtInNames.contains(category.name)
    }
}
