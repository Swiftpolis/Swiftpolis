import SwiftUI
import UniformTypeIdentifiers
import SwiftpolisDomain
import SwiftpolisServices

struct MainWindowView: View {
    let model: AppModel
    @State private var viewModel: MainWindowViewModel
    @Environment(\.openWindow) private var openWindow

    init(model: AppModel) {
        self.model = model
        _viewModel = State(initialValue: MainWindowViewModel(model: model))
    }

    var body: some View {
        Group {
            switch model.state {
            case .starting:
                ProgressView()
            case .ready:
                DownloadsSplitView(viewModel: viewModel)
            case .failed(let message):
                ContentUnavailableView(
                    "Can't Open Your Downloads",
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
            }
        }
        .frame(minWidth: 900, minHeight: 450)
        .onAppear { model.openWindowAction = openWindow }
        .task(id: ReloadTrigger(revision: model.listRevision, category: viewModel.selectedCategoryName, isReady: model.services != nil)) {
            await viewModel.reload()
        }
    }

    private struct ReloadTrigger: Equatable {
        let revision: Int
        let category: String
        let isReady: Bool
    }
}

private struct DownloadsSplitView: View {
    @Bindable var viewModel: MainWindowViewModel
    @SceneStorage("downloadTableColumns") private var columns: TableColumnCustomization<DownloadRow>
    @State private var isConfirmingDelete = false
    @State private var isConfirmingClear = false
    @State private var isChoosingMoveFolder = false
    @AppStorage("suppressesDeleteWarning") private var suppressesDeleteWarning = false
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        NavigationSplitView {
            List(viewModel.categories, id: \.name, selection: $viewModel.selectedCategoryName) { category in
                Text(category.name)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190)
        } detail: {
            VStack(spacing: 0) {
                table
                statusBar
            }
        }
        .navigationTitle("Swiftpolis")
        .toolbar { toolbar }
        .confirmationDialog(
            "This operation will delete downloaded files from your hard disk permanently!",
            isPresented: $isConfirmingDelete
        ) {
            Button("Delete", role: .destructive) { viewModel.removeSelected(deletingFiles: true) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Do you want to continue?")
        }
        .dialogSuppressionToggle("Don't show this message again", isSuppressed: $suppressesDeleteWarning)
        .confirmationDialog(
            "This removes every download and queue from the list. Files on disk stay.",
            isPresented: $isConfirmingClear
        ) {
            Button("Clear Download List", role: .destructive) { viewModel.clearList() }
            Button("Cancel", role: .cancel) {}
        }
        .fileImporter(isPresented: $isChoosingMoveFolder, allowedContentTypes: [.folder]) { result in
            if case .success(let folder) = result { viewModel.moveSelectedFiles(to: folder) }
        }
    }

    private var table: some View {
        Table(viewModel.rows, selection: $viewModel.selection, columnCustomization: $columns) {
            Group {
                TableColumn("File Name", value: \DownloadRow.name).width(min: 120, ideal: 240).customizationID("name")
                TableColumn("Status", value: \DownloadRow.status).width(min: 60, ideal: 90).customizationID("status")
                TableColumn("Size", value: \DownloadRow.size).width(min: 50, ideal: 70).customizationID("size")
                TableColumn("Downloaded", value: \DownloadRow.downloaded).width(min: 50, ideal: 80).customizationID("downloaded")
                TableColumn("Percentage", value: \DownloadRow.percent).width(min: 40, ideal: 70).customizationID("percent")
                TableColumn("Connections", value: \DownloadRow.connections).width(min: 40, ideal: 80).customizationID("connections")
            }
            Group {
                TableColumn("Transfer Rate", value: \DownloadRow.rate).width(min: 50, ideal: 90).customizationID("rate")
                TableColumn("Estimated Time Left", value: \DownloadRow.timeLeft).width(min: 50, ideal: 80).customizationID("timeLeft")
                TableColumn("First Try Date", value: \DownloadRow.firstTry).width(min: 100, ideal: 150).customizationID("firstTry")
                TableColumn("Last Try Date", value: \DownloadRow.lastTry).width(min: 100, ideal: 150).customizationID("lastTry")
                TableColumn("Category", value: \DownloadRow.category).width(min: 80, ideal: 130).customizationID("category")
            }
        }
        .contextMenu(forSelectionType: GID.self) { _ in
            contextMenuItems
        } primaryAction: { _ in
            viewModel.openFile()
        }
    }

    private var statusBar: some View {
        HStack {
            Text(viewModel.selectedLink ?? " ")
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
            Spacer()
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(.bar)
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        let actions = viewModel.actions
        Button("Open File") { viewModel.openFile() }.disabled(!actions.canOpenFile)
        Button("Open Download Folder") { viewModel.openFolder() }.disabled(!actions.canOpenFolder)
        Divider()
        Button("Resume Download") { viewModel.resume() }.disabled(!actions.canResume)
        Button("Pause Download") { viewModel.pause() }.disabled(!actions.canPause)
        Button("Stop Download") { viewModel.stop() }.disabled(!actions.canStop)
        Divider()
        Button("Properties") { viewModel.showProperties() }.disabled(!actions.canEditProperties)
        Button("Progress") { viewModel.showProgress() }.disabled(!actions.canShowProgress)
        Divider()
        Button("Remove Selected Downloads from List") { viewModel.removeSelected(deletingFiles: false) }
            .disabled(!viewModel.hasSelection)
        Button("Delete Selected Download Files") { requestDelete() }
            .disabled(!viewModel.hasSelection)
        Button("Move Selected Download Files to Another Folder...") { isChoosingMoveFolder = true }
            .disabled(!actions.canMoveFile)
    }

    private func requestDelete() {
        if suppressesDeleteWarning {
            viewModel.removeSelected(deletingFiles: true)
        } else {
            isConfirmingDelete = true
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        let actions = viewModel.actions
        ToolbarItemGroup(placement: .primaryAction) {
            Button("Add New Download Link", systemImage: "plus") { openWindow(id: WindowID.addLink) }
            Button("Resume Download", systemImage: "play") { viewModel.resume() }
                .disabled(!actions.canResume)
            Button("Pause Download", systemImage: "pause") { viewModel.pause() }
                .disabled(!actions.canPause)
            Button("Stop Download", systemImage: "stop") { viewModel.stop() }
                .disabled(!actions.canStop)
            Button("Properties", systemImage: "info.circle") { viewModel.showProperties() }
                .disabled(!actions.canEditProperties)
            Button("Progress", systemImage: "gauge.with.dots.needle.50percent") { viewModel.showProgress() }
                .disabled(!actions.canShowProgress)
            Button("Remove Selected Downloads from List", systemImage: "minus.circle") {
                viewModel.removeSelected(deletingFiles: false)
            }
            .disabled(!viewModel.hasSelection)
            Button("Delete Selected Download Files", systemImage: "trash") { requestDelete() }
                .disabled(!viewModel.hasSelection)
            Menu("More", systemImage: "ellipsis") {
                Menu("Sort by") {
                    Button("File Name") { viewModel.sort(by: .name) }
                    Button("File Size") { viewModel.sort(by: .size) }
                    Button("Status") { viewModel.sort(by: .status) }
                    Button("First Try Date") { viewModel.sort(by: .firstTry) }
                    Button("Last Try Date") { viewModel.sort(by: .lastTry) }
                }
                Button("Open Default Download Folder") { viewModel.openDefaultFolder() }
                Button("Stop All Active Downloads") { viewModel.stopAll() }
                Divider()
                Button("Clear Download List") { isConfirmingClear = true }
            }
        }
    }
}
