import SwiftUI
import SwiftpolisDomain

/// A sidebar and a list on iPad, and one stack on iPhone that starts at the list.
struct RootView: View {
    let model: MobileModel
    @State private var viewModel: DownloadListViewModel
    @State private var compactColumn = NavigationSplitViewColumn.detail
    @State private var isShowingSettings = false
    @State private var isNamingQueue = false
    @State private var newQueueName = ""
    @Environment(\.scenePhase) private var scenePhase

    init(model: MobileModel) {
        self.model = model
        _viewModel = State(initialValue: DownloadListViewModel(model: model))
    }

    var body: some View {
        switch model.state {
        case .starting:
            ProgressView()
                .task { await model.start() }
        case .failed(let message):
            ContentUnavailableView("Swiftpolis couldn't start", systemImage: "exclamationmark.triangle", description: Text(message))
        case .ready:
            content
        }
    }

    private var content: some View {
        NavigationSplitView(preferredCompactColumn: $compactColumn) {
            sidebar
        } detail: {
            DownloadListView(viewModel: viewModel)
        }
        .task(id: Reload(revision: model.listRevision, category: viewModel.categoryName)) {
            await viewModel.reload()
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active { model.checkInbox() }
        }
        .onChange(of: model.sharedLinks) { _, links in
            // The list opens the Add Links sheet, and on iPhone it may be off screen.
            if !links.isEmpty { compactColumn = .detail }
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(model: model)
        }
        .alert("New Queue", isPresented: $isNamingQueue) {
            TextField("Name", text: $newQueueName)
            Button("Create") {
                viewModel.createQueue(named: newQueueName)
                newQueueName = ""
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.clearError() } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private struct Reload: Equatable {
        let revision: Int
        let category: String
    }

    private var sidebar: some View {
        List(viewModel.categories, id: \.name, selection: $viewModel.selectedCategoryName) { category in
            Label(category.name, systemImage: icon(for: category))
                .swipeActions {
                    if viewModel.isUserQueue(category), viewModel.canRemoveQueues {
                        Button("Remove", role: .destructive) { viewModel.removeQueue(named: category.name) }
                    }
                }
        }
        .navigationTitle("Swiftpolis")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New Queue", systemImage: "text.badge.plus") { isNamingQueue = true }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button("Settings", systemImage: "gearshape") { isShowingSettings = true }
                    .keyboardShortcut(",")
            }
        }
    }

    private func icon(for category: CategorySummary) -> String {
        switch category.kind {
        case .allDownloads: "tray.full"
        case .singleDownloads: "arrow.down.circle"
        case .queue: "list.number"
        }
    }
}
