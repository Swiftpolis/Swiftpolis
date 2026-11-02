import SwiftUI
import SwiftpolisDomain

struct MainWindowView: View {
    @Bindable var viewModel: MainWindowViewModel

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView()
            case .loaded:
                splitView
            case .failed(let message):
                ContentUnavailableView(
                    "Can't Open Your Downloads",
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
            }
        }
        .frame(minWidth: 700, minHeight: 400)
        .task { await viewModel.load() }
    }

    private var splitView: some View {
        NavigationSplitView {
            List(viewModel.categories, id: \.name, selection: $viewModel.selectedCategoryName) { category in
                Text(category.name)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            ContentUnavailableView(viewModel.selectedCategoryName, systemImage: "arrow.down.circle")
        }
    }
}
