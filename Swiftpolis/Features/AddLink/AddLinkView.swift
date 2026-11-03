import SwiftUI
import SwiftpolisServices

struct AddLinkView: View {
    @State private var viewModel: AddLinkViewModel
    @Environment(\.dismissWindow) private var dismissWindow

    private let model: AppModel
    private let waitingKey: String?

    init(model: AppModel, services: AppModel.Services, waitingKey: String?) {
        self.model = model
        self.waitingKey = waitingKey
        let link = waitingKey.flatMap(model.waitingAddLink)
        _viewModel = State(initialValue: AddLinkViewModel(model: model, services: services, browserLink: link))
    }

    var body: some View {
        VStack(spacing: 0) {
            DownloadOptionsForm(
                draft: $viewModel.draft,
                categories: viewModel.categories,
                createQueue: { name in Task { await viewModel.createQueue(named: name) } }
            ) {
                LabeledContent("File") {
                    Text(viewModel.fileDescription)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            HStack {
                Button("Cancel", role: .cancel) { close() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Download Later") { submit(startNow: false) }
                    .disabled(!viewModel.draft.hasLink)
                Button("OK") { submit(startNow: true) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!viewModel.draft.hasLink)
            }
            .padding()
        }
        .frame(width: 560, height: 480)
        .task { await viewModel.load() }
        .onDisappear {
            if let waitingKey { model.forgetWaitingLinks(waitingKey) }
        }
        .alert("This link has been added before! Are you sure you want to add it again?", isPresented: $viewModel.isAskingAboutDuplicate) {
            Button("Yes") {
                Task { if await viewModel.addDespiteDuplicate() { close() } }
            }
            Button("No", role: .cancel) {}
        }
    }

    private func submit(startNow: Bool) {
        Task { if await viewModel.submit(startNow: startNow) { close() } }
    }

    private func close() {
        dismissWindow(id: WindowID.addLink)
    }
}
