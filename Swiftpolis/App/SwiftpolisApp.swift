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
        // AppDelegate makes sure it opens at launch, even if it was closed when the app last quit.
        .restorationBehavior(.disabled)

        WindowGroup("Add New Download Link", id: WindowID.addLink, for: String.self) { $key in
            if let services = model.services {
                AddLinkView(model: model, services: services, waitingKey: key)
            }
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)

        WindowGroup("Video Finder", id: WindowID.videoFinder, for: String.self) { $key in
            if let services = model.services {
                VideoFinderView(model: model, services: services, waitingKey: key)
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

        MenuBarExtra(isInserted: $model.preferences.showsMenuBarItem) {
            MenuBarContent(model: model)
        } label: {
            MenuBarLabel(model: model, systemImage: "laptopcomputer.and.arrow.down")
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
            Button("Find Video Links...") { openWindow(id: WindowID.videoFinder) }
            Divider()
            Button("Stop All Active Downloads") {
                Task { await model.services?.coordinator.stopAll() }
            }
        }
    }
}
