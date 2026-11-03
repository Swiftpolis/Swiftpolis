import SwiftUI
import SwiftpolisDomain

struct DownloadProgressView: View {
    @State private var viewModel: DownloadProgressViewModel
    @State private var hasStarted = false
    @Environment(\.dismiss) private var dismiss

    init(model: AppModel, services: AppModel.Services, gid: GID) {
        _viewModel = State(initialValue: DownloadProgressViewModel(model: model, services: services, gid: gid))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                row("Link", viewModel.link)
                row("Status", viewModel.status)
                row("Downloaded", viewModel.downloaded)
                row("Transfer rate", viewModel.rate)
                row("Estimated time left", viewModel.timeLeft)
                row("Connections", viewModel.connections)
            }

            if let fraction = viewModel.fraction {
                ProgressView(value: fraction)
            } else {
                ProgressView().progressViewStyle(.linear)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.speedLabel).font(.callout)
                Slider(value: $viewModel.speedDial, in: 0...Double(SpeedDialLabel.maximum), step: 1)
            }

            HStack {
                Spacer()
                Button("Resume") { viewModel.resume() }.disabled(!viewModel.canResume)
                Button("Pause") { viewModel.pause() }.disabled(!viewModel.canPause)
                Button("Stop") { viewModel.stop() }.disabled(!viewModel.canStop)
            }
        }
        .padding()
        .frame(width: 480)
        .navigationTitle(viewModel.title)
        .task { await viewModel.load() }
        .onChange(of: viewModel.isRunning, initial: true) { _, isRunning in
            // Nothing to show once the session ends. It can take a moment to begin, though.
            if isRunning {
                hasStarted = true
            } else if hasStarted {
                dismiss()
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).bold()
            Text(value)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(value)
        }
    }
}
