import Foundation
import Observation
import SwiftpolisBridge
import SwiftpolisDomain
import SwiftpolisEngines
import SwiftpolisPersistence
import SwiftpolisServices

@Observable
final class AddLinksViewModel {
    var text: String {
        didSet {
            if text != oldValue { linksChanged() }
        }
    }
    private(set) var draft: BatchDraft
    private(set) var categories: [String] = [CategoryKind.singleDownloadsName]
    private(set) var errorMessage: String?

    private let model: MobileModel
    private var nameLookup: Task<Void, Never>?

    /// Some servers refuse many requests at once, and these are only for showing names.
    private static let lookupsAtOnce = 4

    init(model: MobileModel, text: String, category: String) {
        self.model = model
        self.text = text
        draft = BatchDraft(preferences: model.preferences, links: [])
        if CategoryKind(categoryName: category) != .allDownloads {
            draft.options.category = category
        }
        linksChanged()
    }

    func load() async {
        await reloadCategories()
    }

    private func reloadCategories() async {
        let names = (try? await model.services?.library.categories().map(\.name)) ?? []
        categories = names.filter { CategoryKind(categoryName: $0) != .allDownloads }
    }

    var category: String {
        get { draft.options.category }
        set { draft.options.category = newValue }
    }

    var usesLogin: Bool {
        get { draft.options.usesLogin }
        set { draft.options.usesLogin = newValue }
    }

    var loginUser: String {
        get { draft.options.loginUser }
        set { draft.options.loginUser = newValue }
    }

    var loginPassword: String {
        get { draft.options.loginPassword }
        set { draft.options.loginPassword = newValue }
    }

    func setSelected(_ isSelected: Bool, id: Int) {
        if let index = draft.items.firstIndex(where: { $0.id == id }) {
            draft.items[index].isSelected = isSelected
        }
    }

    func setAllSelected(_ isSelected: Bool) {
        draft.setAllSelected(isSelected)
    }

    func clearError() {
        errorMessage = nil
    }

    /// Links stay ticked or unticked, and keep their names, as more text arrives.
    private func linksChanged() {
        let previous = draft.items
        var next = BatchDraft(
            preferences: model.preferences,
            links: LinkText.links(in: text).map { BrowserLink(url: $0) }
        )
        next.options = draft.options
        for index in next.items.indices {
            if let same = previous.first(where: { $0.link.url == next.items[index].link.url }) {
                next.items[index].isSelected = same.isSelected
                next.items[index].name = same.name
            }
        }
        draft = next
        lookUpNames()
    }

    private func lookUpNames() {
        nameLookup?.cancel()
        let missing = draft.items.filter { $0.name == nil }.map(\.link.url)
        let settings = model.preferences.engineSettings
        nameLookup = Task {
            try? await Task.sleep(for: .milliseconds(300))
            for start in stride(from: 0, to: missing.count, by: Self.lookupsAtOnce) {
                guard !Task.isCancelled else { return }
                let links = missing[start..<min(start + Self.lookupsAtOnce, missing.count)]
                await withTaskGroup(of: (String, String?).self) { group in
                    for link in links {
                        group.addTask {
                            let request = DownloadRequest(link: link, folder: "", connections: 1)
                            return (link, await Spider.look(at: request, secrets: DownloadSecrets(), settings: settings).fileName)
                        }
                    }
                    for await (link, name) in group {
                        if let name, let index = draft.items.firstIndex(where: { $0.link.url == link }) {
                            draft.items[index].name = name
                        }
                    }
                }
            }
        }
    }

    func createQueue(named name: String) async {
        do {
            try await model.services?.coordinator.createQueue(named: name)
            await reloadCategories()
            category = name
        } catch {
            errorMessage = QueueNaming.message(for: error, name: name)
        }
    }

    /// Adds the ticked links. Returns true once done. Started ones go to the system in the list's order,
    /// either all at once by way of the Queue, or one after another here.
    func add(startsThem: Bool) async -> Bool {
        guard let coordinator = model.services?.coordinator else { return false }
        nameLookup?.cancel()
        if startsThem { model.askToNotify() }
        do {
            var added: [GID] = []
            for addition in draft.selectedInAddingOrder {
                added.append(try await coordinator.add(
                    addition.request,
                    secrets: addition.secrets,
                    to: category,
                    startNow: false
                ))
            }
            guard startsThem else { return true }

            if CategoryKind(categoryName: category) == .queue {
                try await coordinator.startQueue(category)
            } else {
                for gid in added.reversed() {
                    try await coordinator.resume(gid)
                    try? await Task.sleep(for: .milliseconds(50))
                }
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
