import Foundation
import Observation
import SwiftpolisDomain
import SwiftpolisServices
import SwiftpolisPersistence

@Observable
final class PropertiesViewModel {
    var draft: DownloadDraft?
    private(set) var categories: [String] = []
    private(set) var fileName = ""

    private let model: AppModel
    private let services: AppModel.Services
    private let gid: GID

    init(model: AppModel, services: AppModel.Services, gid: GID) {
        self.model = model
        self.services = services
        self.gid = gid
    }

    func load() async {
        guard let download = try? await services.library.download(gid) else { return }
        fileName = download.fileName ?? download.request.link
        let names = (try? await services.library.categories().map(\.name)) ?? []
        categories = names.filter { CategoryKind(categoryName: $0) != .allDownloads }
        draft = DownloadDraft(editing: download, secrets: model.secrets.load(for: gid))
    }

    /// Returns true once saved.
    func save() async -> Bool {
        guard let draft else { return false }
        do {
            try await services.coordinator.update(
                gid,
                request: draft.request,
                secrets: draft.secrets,
                category: draft.category
            )
            return true
        } catch {
            model.notify("Operation was not successful.", body: error.localizedDescription, sound: .fail)
            return false
        }
    }
}
