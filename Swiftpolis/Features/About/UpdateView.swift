import SwiftUI
import SwiftpolisServices

struct UpdateView: View {
    @State private var viewModel: UpdateViewModel
    @Environment(\.openURL) private var openURL
    @Environment(\.dismissWindow) private var dismissWindow

    init(model: AppModel) {
        _viewModel = State(initialValue: UpdateViewModel(model: model))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
            HStack {
                Spacer()
                Button("Close", role: .cancel) { dismissWindow(id: WindowID.updates) }
                    .keyboardShortcut(.cancelAction)
                if case .available(let release) = viewModel.state {
                    Button("Open Release Page") {
                        openURL(release.page)
                        dismissWindow(id: WindowID.updates)
                    }
                    .keyboardShortcut(.defaultAction)
                } else if viewModel.state != .notSetUp {
                    Button("Check Again") { Task { await viewModel.check() } }
                        .disabled(viewModel.state == .checking)
                }
            }
        }
        .padding(20)
        .frame(width: 440)
        .task { await viewModel.check() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .checking:
            HStack {
                ProgressView().controlSize(.small)
                Text("Checking for updates...")
            }
        case .notSetUp:
            message("Updates aren't set up", "This build doesn't name a GitHub repository to check.")
        case .upToDate:
            message("Swiftpolis is up to date", "You have version \(viewModel.currentVersion), the latest one.")
        case .noReleases:
            message("No releases yet", "Nothing has been published for Swiftpolis so far.")
        case .failed(let reason):
            message("Couldn't check for updates", reason)
        case .available(let release):
            message("\(release.version) is available", "You have version \(viewModel.currentVersion).")
            if !release.notes.isEmpty {
                ScrollView {
                    Text(release.notes)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 120, maxHeight: 240)
            }
        }
    }

    private func message(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(detail).foregroundStyle(.secondary).textSelection(.enabled)
        }
    }
}
