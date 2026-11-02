import SwiftUI

@main
struct SwiftpolisApp: App {
    @State private var mainWindowViewModel = MainWindowViewModel(
        makeLibrary: AppDependencies.makeLibrary
    )

    var body: some Scene {
        Window("Swiftpolis", id: "main") {
            MainWindowView(viewModel: mainWindowViewModel)
        }
    }
}
