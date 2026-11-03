import AppKit
import Foundation
import Observation
import SwiftpolisBridge
import SwiftpolisDomain
import SwiftpolisEngines
import SwiftpolisServices
import SwiftpolisPersistence

@Observable
final class VideoFinderViewModel {
    var draft: VideoFinderDraft
    private(set) var categories: [String] = [CategoryKind.singleDownloadsName]
    private(set) var isFetching = false
    private(set) var errorMessage: String?
    private(set) var thumbnail: NSImage?

    private let model: AppModel
    private let services: AppModel.Services
    private var fetchTask: Task<Void, Never>?

    init(model: AppModel, services: AppModel.Services, browserLink: BrowserLink?) {
        self.model = model
        self.services = services
        var options = browserLink.map { DownloadDraft(preferences: model.preferences, browserLink: $0) }
            ?? DownloadDraft(preferences: model.preferences)
        RememberedOptions.restore(into: &options)
        draft = VideoFinderDraft(options: options)
    }

    func load() async {
        let names = (try? await services.library.categories().map(\.name)) ?? []
        categories = names.filter { CategoryKind(categoryName: $0) != .allDownloads }
        await fillLinkFromClipboard()
        #if DEBUG
        if DebugAutomation.fetchesVideoLinks, draft.options.hasLink { fetch() }
        #endif
    }

    /// As in Persepolis, a copied link fills the field. See AddLinkViewModel.
    private func fillLinkFromClipboard() async {
        guard draft.options.link.isEmpty else { return }
        #if DEBUG
        if DebugAutomation.isActive { return }
        #endif
        let pasteboard = NSPasteboard.general
        let patterns = try? await pasteboard.detectedPatterns(for: [\.probableWebURL])
        guard patterns?.contains(\.probableWebURL) == true,
              let text = pasteboard.string(forType: .string),
              LinkText.looksLikeLink(text)
        else { return }
        draft.options.link = text
    }

    // MARK: Finding formats

    var statusMessage: String {
        if isFetching { return "Fetching media information..." }
        if draft.formats == nil, errorMessage == nil {
            return "Please enter a valid video link and press fetch media information."
        }
        return ""
    }

    var duration: String? {
        draft.formats?.durationSeconds.map { DurationFormat.clock(seconds: $0) }
    }

    func fetch() {
        fetchTask?.cancel()
        isFetching = true
        errorMessage = nil
        thumbnail = nil

        let request = draft.options.request
        let secrets = draft.options.secrets
        let settings = model.preferences.engineSettings
        let helpers = model.helpers.paths
        fetchTask = Task {
            do {
                let formats = try await VideoExtractor.formats(
                    at: request.link,
                    request: request,
                    secrets: secrets,
                    settings: settings,
                    helpers: helpers
                )
                draft.apply(formats)
                isFetching = false
                #if DEBUG
                if DebugAutomation.submitsVideoFinder { submitForDebugging() }
                #endif
                await fillIn(formats, request: request, secrets: secrets, settings: settings)
            } catch is CancellationError {
                return
            } catch {
                errorMessage = (error as? VideoExtractor.Failure)?.message ?? error.localizedDescription
                isFetching = false
            }
        }
    }

    /// The picture and any missing sizes come after the lists, which are usable without them.
    private func fillIn(
        _ formats: VideoFormats,
        request: DownloadRequest,
        secrets: DownloadSecrets,
        settings: EngineSettings
    ) async {
        let needingSize = (formats.combined + formats.videoOnly + formats.audioOnly)
            .filter { $0.sizeBytes == nil && $0.isDirect }
        await withTaskGroup(of: Void.self) { group in
            if let link = formats.thumbnail {
                group.addTask { [self] in
                    let data = await VideoExtractor.thumbnail(at: link, request: request, secrets: secrets, settings: settings)
                    await setThumbnail(data)
                }
            }
            for format in needingSize {
                group.addTask { [self] in
                    var sizeRequest = request
                    sizeRequest.link = format.url
                    let findings = await Spider.look(at: sizeRequest, secrets: secrets, settings: settings)
                    if let size = findings.totalBytes, size > 0 {
                        await setSize(size, of: format.id)
                    }
                }
            }
        }
    }

    private func setThumbnail(_ data: Data?) {
        thumbnail = data.flatMap(NSImage.init(data:))
    }

    private func setSize(_ size: Int64, of id: String) {
        guard let formats = draft.formats else { return }
        draft.updateFormats(formats.settingSize(size, forFormat: id))
    }

    // MARK: Adding

    var canSubmit: Bool { draft.formats != nil && !isFetching }

    /// Returns true when the window should close, which includes when nothing was chosen.
    func submit(startNow: Bool) async -> Bool {
        guard let plan = draft.plan else { return true }
        let category = draft.options.category
        let starts = startNow && CategoryKind(categoryName: category) == .singleDownloads
        RememberedOptions.remember(from: draft.options)
        do {
            switch plan {
            case .single(let request, let secrets):
                let gid = try await services.coordinator.add(request, secrets: secrets, to: category, startNow: startNow)
                if starts { model.didStart(gid, isScheduled: request.startTime != nil) }
            case .pair(let video, let audio, let secrets):
                let pair = try await services.coordinator.addVideoPair(
                    video: video,
                    audio: audio,
                    secrets: secrets,
                    to: category,
                    startNow: startNow
                )
                if starts { model.didStart(pair.videoGID, isScheduled: video.startTime != nil) }
            }
            return true
        } catch {
            model.notify("Operation was not successful.", body: error.localizedDescription, sound: .fail)
            return false
        }
    }

    #if DEBUG
    private func submitForDebugging() {
        Task { _ = await submit(startNow: true) }
    }
    #endif
}
