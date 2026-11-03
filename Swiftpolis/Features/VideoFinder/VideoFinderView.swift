import AppKit
import SwiftUI
import SwiftpolisEngines
import SwiftpolisServices

struct VideoFinderView: View {
    @State private var viewModel: VideoFinderViewModel
    @Environment(\.dismissWindow) private var dismissWindow

    private let model: AppModel
    private let waitingKey: String?

    init(model: AppModel, services: AppModel.Services, waitingKey: String?) {
        self.model = model
        self.waitingKey = waitingKey
        let link = waitingKey.flatMap(model.waitingVideoLink)
        _viewModel = State(initialValue: VideoFinderViewModel(model: model, services: services, browserLink: link))
    }

    var body: some View {
        VStack(spacing: 0) {
            DownloadOptionsForm(
                draft: $viewModel.draft.options,
                categories: viewModel.categories,
                showsLinkAndName: false
            ) {
                general
            }
            HStack {
                Button("Cancel", role: .cancel) { close() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Download Later") { submit(startNow: false) }
                    .disabled(!viewModel.canSubmit)
                Button("OK") { submit(startNow: true) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!viewModel.canSubmit)
            }
            .padding()
        }
        .frame(width: 620, height: 620)
        .task { await viewModel.load() }
        .onChange(of: viewModel.movedToBatch) { close() }
        .onDisappear {
            if let waitingKey { model.forgetWaitingLinks(waitingKey) }
        }
    }

    @ViewBuilder
    private var general: some View {
        HStack {
            TextField("Link", text: $viewModel.draft.options.link)
            Button("Fetch Media List") { viewModel.fetch() }
                .disabled(!viewModel.draft.options.hasLink || viewModel.isFetching)
        }
        if let message = viewModel.errorMessage {
            Text(message)
                .foregroundStyle(.red)
                .textSelection(.enabled)
                .lineLimit(4)
        } else if !viewModel.statusMessage.isEmpty {
            Text(viewModel.statusMessage).foregroundStyle(.secondary)
        }
        if let formats = viewModel.draft.formats {
            found(formats)
        }
    }

    @ViewBuilder
    private func found(_ formats: VideoFormats) -> some View {
        HStack(alignment: .top) {
            if let thumbnail = viewModel.thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 72)
            }
            VStack(alignment: .leading) {
                Text(formats.title ?? "").lineLimit(2)
                if let duration = viewModel.duration {
                    Text("Duration \(duration)").foregroundStyle(.secondary)
                }
            }
        }

        if viewModel.draft.showsMediaPicker, !viewModel.draft.usesSeparateStreams {
            Picker("Select a format", selection: $viewModel.draft.mediaChoice) {
                ForEach(Array(formats.combined.enumerated()), id: \.offset) { index, format in
                    Text(format.label).tag(VideoFinderDraft.MediaChoice.combined(index))
                }
                if viewModel.draft.hasBestQualityChoice {
                    Text("Best quality").tag(VideoFinderDraft.MediaChoice.bestQuality)
                }
            }
        }
        if viewModel.draft.canChooseSeparateStreams {
            Toggle("Advanced options", isOn: $viewModel.draft.usesSeparateStreams)
        }
        if viewModel.draft.usesSeparateStreams {
            Picker("Video format", selection: $viewModel.draft.videoChoice) {
                Text("No video").tag(Int?.none)
                ForEach(Array(formats.videoOnly.enumerated()), id: \.offset) { index, format in
                    Text(format.label).tag(Int?.some(index))
                }
            }
            Picker("Audio format", selection: $viewModel.draft.audioChoice) {
                Text("No audio").tag(Int?.none)
                ForEach(Array(formats.audioOnly.enumerated()), id: \.offset) { index, format in
                    Text(format.label).tag(Int?.some(index))
                }
            }
        }

        Toggle("Change file name", isOn: $viewModel.draft.changesName)
        HStack {
            TextField("File name", text: $viewModel.draft.name)
                .disabled(!viewModel.draft.changesName)
            Text(viewModel.draft.fileExtension).foregroundStyle(.secondary)
        }
    }

    private func submit(startNow: Bool) {
        Task { if await viewModel.submit(startNow: startNow) { close() } }
    }

    private func close() {
        dismissWindow(id: WindowID.videoFinder)
    }
}
