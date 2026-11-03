import AppKit
import Observation
import SwiftUI
import SwiftpolisDomain
import SwiftpolisPersistence
import SwiftpolisServices

@Observable
final class AfterDownloadViewModel {
    private(set) var fileName = ""
    private(set) var filePath = ""
    private(set) var link = ""
    private(set) var size = ""
    var doesNotShowAgain = false

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
        fileName = download.fileName ?? ""
        filePath = download.filePath ?? ""
        link = download.request.link
        size = download.totalBytes.map(ByteFormat.size) ?? ""
    }

    func openFile() {
        NSWorkspace.shared.open(URL(filePath: filePath))
    }

    func openFolder() {
        NSWorkspace.shared.activateFileViewerSelecting([URL(filePath: filePath)])
    }

    func saveChoice() {
        if doesNotShowAgain { model.preferences.showsAfterDownloadDialog = false }
    }
}

struct AfterDownloadView: View {
    @State private var viewModel: AfterDownloadViewModel
    @Environment(\.dismiss) private var dismiss

    init(model: AppModel, services: AppModel.Services, gid: GID) {
        _viewModel = State(initialValue: AfterDownloadViewModel(model: model, services: services, gid: gid))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Download Complete").font(.title3).bold()
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                row("File name", viewModel.fileName)
                row("Size", viewModel.size)
                row("Link", viewModel.link)
                row("Save as", viewModel.filePath)
            }
            Toggle("Don't show this message again", isOn: $viewModel.doesNotShowAgain)
            HStack {
                Button("Open File") {
                    viewModel.openFile()
                    close()
                }
                Button("Open Download Folder") {
                    viewModel.openFolder()
                    close()
                }
                Spacer()
                Button("OK") { close() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 500)
        .navigationTitle(viewModel.fileName)
        .task { await viewModel.load() }
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).bold()
            Text(value)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .help(value)
        }
    }

    private func close() {
        viewModel.saveChoice()
        dismiss()
    }
}
