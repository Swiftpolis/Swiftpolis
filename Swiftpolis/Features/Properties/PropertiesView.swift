import SwiftUI
import SwiftpolisDomain
import SwiftpolisServices

struct PropertiesView: View {
    @State private var viewModel: PropertiesViewModel
    @Environment(\.dismiss) private var dismiss

    init(model: AppModel, services: AppModel.Services, gid: GID) {
        _viewModel = State(initialValue: PropertiesViewModel(model: model, services: services, gid: gid))
    }

    var body: some View {
        VStack(spacing: 0) {
            if let binding = Binding($viewModel.draft) {
                DownloadOptionsForm(draft: binding, categories: viewModel.categories) {
                    LabeledContent("File") {
                        Text(viewModel.fileName)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                HStack {
                    Spacer()
                    Button("Cancel", role: .cancel) { dismiss() }
                        .keyboardShortcut(.cancelAction)
                    Button("OK") {
                        Task { if await viewModel.save() { dismiss() } }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!binding.wrappedValue.hasLink)
                }
                .padding()
            } else {
                ProgressView()
            }
        }
        .frame(width: 560, height: 480)
        .task { await viewModel.load() }
    }
}
