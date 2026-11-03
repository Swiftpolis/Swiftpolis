import Foundation
import Observation
import SwiftpolisServices

@Observable
final class UpdateViewModel {
    enum State: Equatable {
        case checking
        case notSetUp
        case upToDate
        case noReleases
        case available(AppRelease)
        case failed(String)
    }

    private(set) var state = State.checking

    private let model: AppModel

    init(model: AppModel) {
        self.model = model
    }

    var currentVersion: String { model.appVersion }

    func check() async {
        guard let checker = model.updateChecker else {
            state = .notSetUp
            return
        }
        state = .checking
        do {
            switch try await checker.check(currentVersion: currentVersion) {
            case .upToDate: state = .upToDate
            case .noReleases: state = .noReleases
            case .available(let release): state = .available(release)
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
