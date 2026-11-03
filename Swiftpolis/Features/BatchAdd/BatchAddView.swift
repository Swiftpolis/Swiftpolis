import SwiftUI
import UniformTypeIdentifiers
import SwiftpolisBridge
import SwiftpolisServices

/// Picks from several links at once, for a browser's links, a text file or the clipboard.
struct BatchAddView: View {
    @State private var viewModel: BatchAddViewModel
    @State private var isChoosingFolder = false
    @State private var isNamingQueue = false
    @State private var newQueueName = "queue"
    @Environment(\.dismiss) private var dismiss

    init(model: AppModel, services: AppModel.Services, links: [BrowserLink]) {
        _viewModel = State(initialValue: BatchAddViewModel(model: model, services: services, links: links))
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView {
                Tab("Links", systemImage: "link") { linksTab }
                Tab("Download Options", systemImage: "gearshape") { optionsTab }
            }
            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("OK") {
                    Task { if await viewModel.add() { dismiss() } }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!viewModel.draft.hasSelection)
            }
            .padding()
        }
        .frame(width: 640, height: 480)
        .task { await viewModel.load() }
        .alert("Enter queue name:", isPresented: $isNamingQueue) {
            TextField("Queue", text: $newQueueName)
            Button("OK") {
                Task { await viewModel.createQueue(named: newQueueName) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var linksTab: some View {
        VStack(alignment: .leading) {
            List($viewModel.draft.items) { $item in
                Toggle(isOn: $item.isSelected) {
                    VStack(alignment: .leading) {
                        Text(item.shownName).lineLimit(1).truncationMode(.middle)
                        Text(item.link.url)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
            HStack {
                Button("Select All") { viewModel.setAllSelected(true) }
                Button("Deselect All") { viewModel.setAllSelected(false) }
                Spacer()
                Picker("Add to category:", selection: $viewModel.draft.options.category) {
                    ForEach(viewModel.categories, id: \.self) { Text($0) }
                }
                .fixedSize()
                Button("New Queue") { isNamingQueue = true }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    private var optionsTab: some View {
        Form {
            Section {
                LabeledContent("Download folder") {
                    HStack {
                        Text(viewModel.draft.options.folder).lineLimit(1).truncationMode(.middle)
                        Button("Change") { isChoosingFolder = true }
                    }
                }
                Stepper(
                    "Number of connections: \(viewModel.draft.options.connections)",
                    value: $viewModel.draft.options.connections,
                    in: 1...64
                )
            }
            ProxyFields(draft: $viewModel.draft.options)
            LoginFields(draft: $viewModel.draft.options)
        }
        .formStyle(.grouped)
        .fileImporter(isPresented: $isChoosingFolder, allowedContentTypes: [.folder]) { result in
            if case .success(let folder) = result { viewModel.draft.options.folder = folder.path }
        }
    }
}
