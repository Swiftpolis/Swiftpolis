import Foundation
import Observation
import SwiftpolisDomain
import SwiftpolisEngines
import SwiftpolisServices
import SwiftpolisPersistence

@Observable
final class DownloadProgressViewModel {
    var speedDial = Double(SpeedDialLabel.maximum) {
        didSet { applySpeedDial() }
    }
    var shutsDownAfterwards = false {
        didSet {
            let isOn = shutsDownAfterwards
            Task { await services.coordinator.setShutdownAfterDownload(isOn, for: gid) }
        }
    }
    private(set) var link = ""
    private(set) var savedName: String?

    let gid: GID
    private let model: AppModel
    private let services: AppModel.Services

    init(model: AppModel, services: AppModel.Services, gid: GID) {
        self.model = model
        self.services = services
        self.gid = gid
    }

    func load() async {
        let download = try? await services.library.download(gid)
        link = download?.request.link ?? ""
        savedName = download?.fileName
    }

    private var snapshot: DownloadSnapshot? { model.snapshots[gid] }

    /// Whether the Download has a session. Once it doesn't, its progress window closes.
    var isRunning: Bool { snapshot != nil }

    var title: String {
        let name = snapshot?.fileName ?? savedName ?? "Download"
        guard let snapshot, snapshot.percent > 0 else { return name }
        return "(\(snapshot.percent)%)\(name)"
    }

    var status: String { snapshot?.status.rawValue ?? "" }

    var downloaded: String {
        guard let snapshot else { return "" }
        let done = ByteFormat.size(snapshot.downloadedBytes)
        return snapshot.totalBytes.map { "\(done)/\(ByteFormat.size($0))" } ?? done
    }

    var rate: String { snapshot.map { ByteFormat.speed($0.bytesPerSecond) } ?? "" }
    var timeLeft: String { snapshot?.secondsRemaining.map(DurationFormat.remaining(seconds:)) ?? "" }
    var connections: String { snapshot.map { String($0.activeConnections) } ?? "" }

    /// `nil` when progress can't be measured yet, which shows as a busy bar.
    var fraction: Double? {
        guard let snapshot, snapshot.percent > 0 else { return nil }
        return Double(snapshot.percent) / 100
    }

    var canResume: Bool { snapshot?.status == .paused }
    var canPause: Bool { snapshot?.status == .downloading }
    var canStop: Bool { snapshot != nil && snapshot?.status != .stopped }

    var speedLabel: String { SpeedDialLabel.text(for: Int(speedDial)) }

    func resume() {
        Task { try? await services.coordinator.resume(gid) }
    }

    func pause() {
        Task { try? await services.coordinator.pause(gid) }
    }

    func stop() {
        Task { try? await services.coordinator.stop(gid) }
    }

    private func applySpeedDial() {
        let dial = Int(speedDial)
        Task { await services.coordinator.setSpeedDial(dial, for: gid) }
    }
}

enum SpeedDialLabel {
    static let maximum = 10

    static func text(for dial: Int) -> String {
        switch dial {
        case maximum: "Speed : Maximum"
        case 0: "Speed : Minimum"
        default: "Speed"
        }
    }
}
