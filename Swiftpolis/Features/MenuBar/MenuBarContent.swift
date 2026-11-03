import AppKit
import SwiftUI
import SwiftpolisServices

/// The menu bar item, which replaces Persepolis's system tray icon.
struct MenuBarContent: View {
    let model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Add New Download Link") {
            openWindow(id: WindowID.addLink)
            NSApp.activate()
        }
        Button("Find Video Links...") {
            openWindow(id: WindowID.videoFinder)
            NSApp.activate()
        }
        Button("Stop All Active Downloads") {
            Task { await model.services?.coordinator.stopAll() }
        }
        Divider()
        Button("Show Main Window") {
            openWindow(id: WindowID.main)
            NSApp.activate()
        }
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
