import AppKit
import SwiftUI
import SwiftpolisServices

/// The menu bar item, which replaces Persepolis's system tray icon.
struct MenuBarContent: View {
    let model: AppModel

    var body: some View {
        Button("Add New Download Link") {
            model.present(id: WindowID.addLink)
        }
        Button("Find Video Links...") {
            model.present(id: WindowID.videoFinder)
        }
        Button("Stop All Active Downloads") {
            Task { await model.services?.coordinator.stopAll() }
        }
        Divider()
        Button("Show Main Window") {
            model.present(id: WindowID.main)
        }
        Button("About Swiftpolis") { model.present(id: WindowID.about) }
        Button("Check for Updates...") { model.present(id: WindowID.updates) }
        Button("Exit") { NSApp.terminate(nil) }
    }
}

/// The menu bar icon. It exists before any window, so it's what gives the app its way to open them.
struct MenuBarLabel: View {
    let model: AppModel
    let systemImage: String
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(systemName: systemImage)
            .onAppear {
                model.openWindowAction = openWindow
                model.drainInbox()
            }
    }
}
