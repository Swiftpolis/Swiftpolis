import AppKit
import Foundation
import Observation
import SwiftpolisBridge
import SwiftpolisDomain
import SwiftpolisEngines
import SwiftpolisServices
import SwiftpolisPersistence

@Observable
final class AddLinkViewModel {
    var draft: DownloadDraft {
        didSet {
            if draft.link != oldValue.link { lookUpLink() }
        }
    }
    private(set) var categories: [String] = [CategoryKind.singleDownloadsName]
    private(set) var foundName: String?
    private(set) var foundSize: String?
    var isAskingAboutDuplicate = false

    private let model: AppModel
    private let services: AppModel.Services
    private var spiderTask: Task<Void, Never>?
    private var pendingStart = false

    init(model: AppModel, services: AppModel.Services, browserLink: BrowserLink?) {
        self.model = model
        self.services = services
        var draft = browserLink.map { DownloadDraft(preferences: model.preferences, browserLink: $0) }
            ?? DownloadDraft(preferences: model.preferences)
        RememberedOptions.restore(into: &draft)
        self.draft = draft
        lookUpLink()
    }

    func load() async {
        await reloadCategories()
        await fillLinkFromClipboard()
    }

    private func reloadCategories() async {
        let names = (try? await services.library.categories().map(\.name)) ?? []
        categories = names.filter { CategoryKind(categoryName: $0) != .allDownloads }
    }

    /// Creates a Queue from this window, and adds to it.
    func createQueue(named name: String) async {
        do {
            try await services.coordinator.createQueue(named: name)
            await reloadCategories()
            draft.category = name
        } catch {
            model.notify("Operation was not successful.", body: QueueNaming.message(for: error, name: name), sound: .fail)
        }
    }

    /// As in Persepolis, a copied link fills the field. Looking for a link pattern first means the
    /// clipboard is only read when there's something worth reading.
    private func fillLinkFromClipboard() async {
        guard draft.link.isEmpty else { return }
        #if DEBUG
        // Automated runs must not read whatever the person at this Mac has copied.
        if DebugAutomation.isActive { return }
        #endif
        let pasteboard = NSPasteboard.general
        let patterns = try? await pasteboard.detectedPatterns(for: [\.probableWebURL])
        guard patterns?.contains(\.probableWebURL) == true,
              let text = pasteboard.string(forType: .string),
              LinkText.looksLikeLink(text)
        else { return }
        draft.link = text
    }

    /// Asks the server for the file's name and size as the link is typed.
    private func lookUpLink() {
        spiderTask?.cancel()
        foundName = nil
        foundSize = nil
        guard draft.hasLink else { return }
        let request = draft.request
        let secrets = draft.secrets
        let settings = model.preferences.engineSettings
        spiderTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            let findings = await Spider.look(at: request, secrets: secrets, settings: settings)
            guard !Task.isCancelled else { return }
            foundName = findings.fileName
            foundSize = findings.totalBytes.map(ByteFormat.size)
        }
    }

    var fileDescription: String {
        guard draft.hasLink else { return " " }
        let name = foundName ?? "***"
        return foundSize.map { "\(name) (\($0))" } ?? name
    }

    // MARK: Adding

    /// Returns true once the Download is added. A link added before needs asking about first.
    func submit(startNow: Bool) async -> Bool {
        let isDuplicate = (try? await services.library.containsLink(draft.request.link)) ?? false
        if isDuplicate {
            pendingStart = startNow
            isAskingAboutDuplicate = true
            return false
        }
        return await add(startNow: startNow)
    }

    func addDespiteDuplicate() async -> Bool {
        await add(startNow: pendingStart)
    }

    private func add(startNow: Bool) async -> Bool {
        RememberedOptions.remember(from: draft)
        do {
            let gid = try await services.coordinator.add(
                draft.request,
                secrets: draft.secrets,
                to: draft.category,
                startNow: startNow
            )
            if startNow, CategoryKind(categoryName: draft.category) == .singleDownloads {
                model.didStart(gid, isScheduled: draft.request.startTime != nil)
            }
            return true
        } catch {
            model.notify("Operation was not successful.", body: error.localizedDescription, sound: .fail)
            return false
        }
    }
}
