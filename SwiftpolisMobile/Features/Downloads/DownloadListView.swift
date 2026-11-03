import QuickLook
import SwiftUI
import UIKit
import SwiftpolisDomain

struct DownloadListView: View {
    @Bindable var viewModel: DownloadListViewModel
    @State private var addSheet: AddSheet?
    @State private var previewURL: URL?
    @State private var isEditingQueue = false
    @Environment(\.editMode) private var editMode
    @Environment(\.openURL) private var openURL

    /// A sheet to add links, already holding any that were pasted or dropped.
    private struct AddSheet: Identifiable {
        let id = UUID()
        let text: String
    }

    var body: some View {
        List(selection: $viewModel.selection) {
            if let summary = viewModel.summary {
                Section(summary) {
                    ForEach(viewModel.items) { item in
                        row(item).tag(item.id)
                    }
                }
            }
        }
        .overlay {
            if viewModel.items.isEmpty { emptyState }
        }
        .navigationTitle(viewModel.categoryName)
        .toolbar { toolbar }
        .modifier(PastingLinks { addSheet = AddSheet(text: $0) })
        .dropDestination(for: String.self) { texts, _ in
            addSheet = AddSheet(text: texts.joined(separator: "\n"))
            return true
        }
        .sheet(item: $addSheet) { sheet in
            AddLinksView(model: viewModel.model, text: sheet.text, category: viewModel.categoryName)
        }
        .sheet(isPresented: $isEditingQueue) {
            if let queue = viewModel.selectedQueue {
                QueueOptionsView(queue: queue) { viewModel.saveOptions($0, forQueue: queue.name) }
            }
        }
        .quickLookPreview($previewURL)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Downloads", systemImage: "arrow.down.circle")
        } description: {
            Text("Add one link, or paste a whole list of them. Downloads carry on when you leave the app.")
        } actions: {
            Button("Add Links") { addSheet = AddSheet(text: "") }
                .buttonStyle(.borderedProminent)
            PasteButton(payloadType: String.self) { texts in
                addSheet = AddSheet(text: texts.joined(separator: "\n"))
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button("Add Links", systemImage: "plus") { addSheet = AddSheet(text: "") }
                .keyboardShortcut("n")
        }
        if viewModel.selectedQueue != nil {
            ToolbarItem(placement: .primaryAction) {
                if viewModel.isSelectedQueueRunning {
                    Button("Stop Queue", systemImage: "stop.fill") { viewModel.stopSelectedQueue() }
                } else {
                    Button("Start Queue", systemImage: "play.fill") { viewModel.startSelectedQueue() }
                        .disabled(viewModel.items.isEmpty)
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button("Queue Options", systemImage: "slider.horizontal.3") { isEditingQueue = true }
                    .disabled(viewModel.isSelectedQueueRunning)
            }
        }
        ToolbarItem(placement: .secondaryAction) {
            Button("Stop All", systemImage: "stop.circle") { viewModel.stopAll() }
        }
        ToolbarItem(placement: .topBarLeading) {
            EditButton().disabled(viewModel.items.isEmpty)
        }
        if editMode?.wrappedValue.isEditing == true {
            ToolbarItemGroup(placement: .bottomBar) {
                Button("Resume") { viewModel.resume(viewModel.selection) }
                    .disabled(!canResumeSelection)
                Spacer()
                Button("Remove", role: .destructive) {
                    viewModel.remove(viewModel.selection, deletingFiles: false)
                }
                .disabled(viewModel.selection.isEmpty)
            }
        }
    }

    private var canResumeSelection: Bool {
        let selected = viewModel.items.filter { viewModel.selection.contains($0.id) }
        return !selected.isEmpty && selected.allSatisfy(\.canResume)
    }

    private func row(_ item: DownloadItem) -> some View {
        DownloadRow(item: item)
            .contentShape(Rectangle())
            .onTapGesture {
                if let url = item.fileURL { previewURL = url }
            }
            .swipeActions(edge: .leading) {
                if item.canResume {
                    Button("Resume", systemImage: "play.fill") { viewModel.resume([item.id]) }.tint(.green)
                } else if item.canPause {
                    Button("Pause", systemImage: "pause.fill") { viewModel.pause(item.id) }.tint(.orange)
                }
            }
            .swipeActions(edge: .trailing) {
                if item.canStop {
                    Button("Stop", systemImage: "stop.fill") { viewModel.stop(item.id) }.tint(.gray)
                } else {
                    Button("Remove", systemImage: "trash", role: .destructive) {
                        viewModel.remove([item.id], deletingFiles: false)
                    }
                }
            }
            .contextMenu { menu(for: item) }
    }

    @ViewBuilder
    private func menu(for item: DownloadItem) -> some View {
        if let url = item.fileURL {
            Button("Open", systemImage: "eye") { previewURL = url }
            ShareLink(item: url)
            Button("Show in Files", systemImage: "folder") { showInFiles(url) }
        }
        if item.canResume {
            Button("Resume", systemImage: "play.fill") { viewModel.resume([item.id]) }
        }
        if item.canPause {
            Button("Pause", systemImage: "pause.fill") { viewModel.pause(item.id) }
        }
        if item.canStop {
            Button("Stop", systemImage: "stop.fill") { viewModel.stop(item.id) }
        }
        Button("Copy Link", systemImage: "link") { UIPasteboard.general.string = item.link }
        if !item.canStop {
            Button("Remove from List", systemImage: "minus.circle") {
                viewModel.remove([item.id], deletingFiles: false)
            }
            if item.fileURL != nil {
                Button("Delete File", systemImage: "trash", role: .destructive) {
                    viewModel.remove([item.id], deletingFiles: true)
                }
            }
        }
    }

    /// The Files app's own link to a place.
    private func showInFiles(_ url: URL) {
        let folder = url.deletingLastPathComponent().path
        let encoded = folder.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? folder
        if let link = URL(string: "shareddocuments://" + encoded) { openURL(link) }
    }
}

/// Pressing Command-V on the list. Without it, a keyboard user pastes in the Add Links sheet.
private struct PastingLinks: ViewModifier {
    let paste: (String) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 27, *) {
            content.pasteDestination(for: String.self) { paste($0.joined(separator: "\n")) }
        } else {
            content
        }
    }
}

private struct DownloadRow: View {
    let item: DownloadItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .imageScale(.large)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .lineLimit(2)
                    .truncationMode(.middle)
                if let fraction = item.fraction {
                    ProgressView(value: fraction)
                }
                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(item.status == .error ? .red : .secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }

    private var icon: String {
        switch item.status {
        case .complete: "checkmark.circle.fill"
        case .error: "exclamationmark.circle.fill"
        case .downloading: "arrow.down.circle"
        case .paused: "pause.circle"
        case .scheduled: "clock"
        case .stopped: "stop.circle"
        case .waiting, .creatingDownloadFile: "hourglass"
        }
    }

    private var iconColor: Color {
        switch item.status {
        case .complete: .green
        case .error: .red
        case .downloading: .accentColor
        default: .secondary
        }
    }
}

/// A Queue's options. iOS can't be relied on to wake the app for an End time, so there's only a Start time.
struct QueueOptionsView: View {
    let queue: CategorySummary
    let save: (QueueOptions) -> Void
    @State private var options: QueueOptions
    @State private var startTime: Date
    @Environment(\.dismiss) private var dismiss

    init(queue: CategorySummary, save: @escaping (QueueOptions) -> Void) {
        self.queue = queue
        self.save = save
        _options = State(initialValue: queue.options)
        var parts = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        parts.hour = queue.options.startTime.hour
        parts.minute = queue.options.startTime.minute
        _startTime = State(initialValue: Calendar.current.date(from: parts) ?? .now)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Start at a set time", isOn: $options.startTimeEnabled)
                    if options.startTimeEnabled {
                        DatePicker("Start time", selection: $startTime, displayedComponents: .hourAndMinute)
                    }
                } footer: {
                    Text("Press Start Queue first. The system starts them at about this time, even with the app closed.")
                }
                Section {
                    Toggle("Oldest first", isOn: $options.isReversed)
                }
            }
            .navigationTitle(queue.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let parts = Calendar.current.dateComponents([.hour, .minute], from: startTime)
                        options.startTime = ClockTime(hour: parts.hour ?? 0, minute: parts.minute ?? 0) ?? options.startTime
                        save(options)
                        dismiss()
                    }
                }
            }
        }
    }
}
