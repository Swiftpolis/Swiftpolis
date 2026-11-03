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
    @State private var isNamingQueue = false
    @State private var newQueueName = "queue"
    @State private var isConfirmingRemoveQueue = false
    @AppStorage("suppressesRemoveQueueWarning") private var suppressesRemoveQueueWarning = false
    @AppStorage("suppressesDeleteWarning") private var suppressesDeleteWarning = false
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        NavigationSplitView {
            List(viewModel.categories, id: \.name, selection: $viewModel.selectedCategoryName) { category in
                Text(category.name)
            }
            .safeAreaInset(edge: .bottom) {
                if viewModel.isQueueSelected {
                    QueuePanel(viewModel: viewModel)
                }
            }
            .navigationSplitViewColumnWidth(min: 230, ideal: 250)
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
        .alert("Enter queue name:", isPresented: $isNamingQueue) {
            TextField("Queue", text: $newQueueName)
            Button("OK") { viewModel.createQueue(named: newQueueName) }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "This operation will remove all download items in this queue from \"All Downloads\" list!",
            isPresented: $isConfirmingRemoveQueue
        ) {
            Button("Remove Queue", role: .destructive) { viewModel.removeSelectedQueue() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Do you want to continue?")
        }
        .dialogSuppressionToggle("Don't show this message again", isSuppressed: $suppressesRemoveQueueWarning)
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
        Divider()
        Menu("Add to") {
            ForEach(viewModel.moveTargets, id: \.self) { category in
                Button(category) { viewModel.moveSelection(toCategory: category) }
            }
        }
        .disabled(!viewModel.hasSelection)
        if viewModel.isQueueSelected {
            Button("Move Selected Items Up") { viewModel.moveSelection(.up) }
                .disabled(!viewModel.canMoveSelection)
            Button("Move Selected Items Down") { viewModel.moveSelection(.down) }
                .disabled(!viewModel.canMoveSelection)
        }
    }

    private func requestRemoveQueue() {
        if suppressesRemoveQueueWarning {
            viewModel.removeSelectedQueue()
        } else {
            isConfirmingRemoveQueue = true
        }
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
            if viewModel.isQueueSelected {
                Button("Move Selected Items Up", systemImage: "arrow.up") { viewModel.moveSelection(.up) }
                    .disabled(!viewModel.canMoveSelection)
                Button("Move Selected Items Down", systemImage: "arrow.down") { viewModel.moveSelection(.down) }
                    .disabled(!viewModel.canMoveSelection)
            }
            Menu("More", systemImage: "ellipsis") {
                Button("Create New Queue...") {
                    newQueueName = "queue"
                    isNamingQueue = true
                }
                Button("Remove Queue") { requestRemoveQueue() }
                    .disabled(!viewModel.canRemoveSelectedQueue)
                Divider()
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

/// The side panel's options for the selected Queue. Which ones show depends on whether it's running.
private struct QueuePanel: View {
    @Bindable var viewModel: MainWindowViewModel
    @State private var options = QueueOptions()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.isSelectedQueueRunning {
                runningControls
            } else {
                stoppedControls
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
        .task(id: viewModel.selectedCategoryName) {
            options = viewModel.selectedCategory?.options ?? QueueOptions()
        }
    }

    private var stoppedControls: some View {
        Group {
            HStack {
                Toggle("Start time", isOn: $options.startTimeEnabled)
                Spacer()
                ClockTimePicker("Start time", time: $options.startTime)
                    .labelsHidden()
                    .disabled(!options.startTimeEnabled)
            }
            HStack {
                Toggle("End time", isOn: $options.endTimeEnabled)
                Spacer()
                ClockTimePicker("End time", time: $options.endTime)
                    .labelsHidden()
                    .disabled(!options.endTimeEnabled)
            }
            Toggle("Download bottom of the list first", isOn: $options.isReversed)
            Text(ScheduleNotes.short)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(4)
                .help(ScheduleNotes.text)
            Button("Start Queue") {
                viewModel.updateSelectedQueueOptions(options)
                viewModel.startSelectedQueue()
            }
            .frame(maxWidth: .infinity)
        }
        .onChange(of: options) { _, new in viewModel.updateSelectedQueueOptions(new) }
    }

    private var runningControls: some View {
        Group {
            Text(SpeedDialLabel.text(for: Int(viewModel.selectedQueueDial))).font(.callout)
            Slider(
                value: Binding(get: { viewModel.selectedQueueDial }, set: { viewModel.selectedQueueDial = $0 }),
                in: 0...Double(SpeedDialLabel.maximum),
                step: 1
            )
            Toggle(
                "Shut down the Mac when this queue finishes",
                isOn: Binding(get: { viewModel.selectedQueueShutsDown }, set: { viewModel.selectedQueueShutsDown = $0 })
            )
            Button("Stop Queue") { viewModel.stopSelectedQueue() }
                .frame(maxWidth: .infinity)
        }
    }
}
