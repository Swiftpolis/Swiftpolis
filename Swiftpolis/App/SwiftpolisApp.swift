import SwiftUI
import SwiftpolisDomain
import SwiftpolisServices

@main
struct SwiftpolisApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel.shared

    var body: some Scene {
        Window("Swiftpolis", id: WindowID.main) {
            MainWindowView(model: model)
        }
        .commands { AppCommands(model: model) }

        WindowGroup("Add New Download Link", id: WindowID.addLink, for: String.self) { $key in
            if let services = model.services {
                AddLinkView(model: model, services: services, waitingKey: key)
            }
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)

        WindowGroup("Add Links", id: WindowID.batchAdd, for: String.self) { $key in
            if let services = model.services, let key, let links = model.waitingBatch(key) {
                BatchAddView(model: model, services: services, links: links)
                    .onDisappear { model.forgetWaitingLinks(key) }
            }
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)

        WindowGroup(id: WindowID.progress, for: String.self) { $gid in
            if let services = model.services, let gid = gid.flatMap(GID.init(rawValue:)) {
                DownloadProgressView(model: model, services: services, gid: gid)
            }
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)

        WindowGroup("Properties", id: WindowID.properties, for: String.self) { $gid in
            if let services = model.services, let gid = gid.flatMap(GID.init(rawValue:)) {
                PropertiesView(model: model, services: services, gid: gid)
            }
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)

        WindowGroup(id: WindowID.afterDownload, for: String.self) { $gid in
            if let services = model.services, let gid = gid.flatMap(GID.init(rawValue:)) {
                AfterDownloadView(model: model, services: services, gid: gid)
            }
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)

        Settings {
            PreferencesView(model: model)
        }

        MenuBarExtra("Swiftpolis", systemImage: "arrow.down.circle", isInserted: $model.preferences.showsMenuBarItem) {
            MenuBarContent(model: model)
        }
    }
}

struct AppCommands: Commands {
    let model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Add New Download Link") { openWindow(id: WindowID.addLink) }
                .keyboardShortcut("n")
            Divider()
            Button("Stop All Active Downloads") {
                Task { await model.services?.coordinator.stopAll() }
            }
        }
    }
}
