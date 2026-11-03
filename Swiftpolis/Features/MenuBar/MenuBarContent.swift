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
        Button("Stop All Active Downloads") {
            Task { await model.services?.coordinator.stopAll() }
        }
        Divider()
        Button("Show Main Window") {
            openWindow(id: WindowID.main)
            NSApp.activate()
        }
        Button("Exit") { NSApp.terminate(nil) }
            .onAppear { model.openWindowAction = openWindow }
    }
}
