import Foundation
import Observation
import SwiftpolisBridge
import SwiftpolisDomain
import SwiftpolisEngines
import SwiftpolisPersistence
import SwiftpolisServices

@Observable
final class BatchAddViewModel {
    var draft: BatchDraft
    private(set) var categories: [String] = [CategoryKind.singleDownloadsName]

    private let model: AppModel
    private let services: AppModel.Services

    init(model: AppModel, services: AppModel.Services, links: [BrowserLink]) {
        self.model = model
        self.services = services
        draft = BatchDraft(preferences: model.preferences, links: links)
    }

    func load() async {
        await reloadCategories()
        await lookUpNames()
    }

    private func reloadCategories() async {
        let names = (try? await services.library.categories().map(\.name)) ?? []
        categories = names.filter { CategoryKind(categoryName: $0) != .allDownloads }
    }

    /// Asks each server for its file's name. Links with a name already, or that don't answer, stay as
    /// they are.
    private func lookUpNames() async {
        let settings = model.preferences.engineSettings
        await withTaskGroup(of: (Int, String?).self) { group in
            for item in draft.items where item.name == nil {
                let link = item.link
                group.addTask {
                    var request = DownloadRequest(link: link.url, folder: "", connections: 1)
                    request.referer = link.referrer
                    request.userAgent = link.userAgent
                    request.headers = link.headers
                    request.cookieFilePath = link.cookieFilePath
                    let secrets = DownloadSecrets(cookieHeader: link.cookies)
                    return (item.id, await Spider.look(at: request, secrets: secrets, settings: settings).fileName)
                }
            }
            for await (id, name) in group {
                if let index = draft.items.firstIndex(where: { $0.id == id }), let name {
                    draft.items[index].name = name
                }
            }
        }
    }

    func setAllSelected(_ isSelected: Bool) {
        draft.setAllSelected(isSelected)
    }

    func createQueue(named name: String) async {
        do {
            try await services.coordinator.createQueue(named: name)
            await reloadCategories()
            draft.options.category = name
        } catch {
            model.notify("Operation was not successful.", body: QueueNaming.message(for: error, name: name), sound: .fail)
        }
    }

    /// Adds the selected links, none of them started, as in Persepolis. Returns true once done.
    func add() async -> Bool {
        do {
            for addition in draft.selectedInAddingOrder {
                try await services.coordinator.add(
                    addition.request,
                    secrets: addition.secrets,
                    to: draft.options.category,
                    startNow: false
                )
            }
            return true
        } catch {
            model.notify("Operation was not successful.", body: error.localizedDescription, sound: .fail)
            return false
        }
    }
}
