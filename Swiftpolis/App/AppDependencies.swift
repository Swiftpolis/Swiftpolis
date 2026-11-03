import Foundation
import SwiftpolisBridge
import SwiftpolisPersistence
import SwiftpolisServices

/// Builds the objects the app shares. This is the only place that knows where things are stored.
nonisolated enum AppDependencies {
    struct Environment {
        let dataFolder: URL
        let preferences: PreferencesStore
        let secrets: any SecretStore
        let inbox: BrowserInbox?
        let helpers: HelperInstallation
    }

    static func environment() -> Environment {
        #if DEBUG
        if let debug = DebugAutomation.environment() { return debug }
        #endif
        let dataFolder = URL.applicationSupportDirectory.appending(path: "Swiftpolis", directoryHint: .isDirectory)
        return Environment(
            dataFolder: dataFolder,
            preferences: PreferencesStore(),
            secrets: KeychainSecretStore(),
            inbox: BrowserInbox.shared,
            helpers: helpers(in: dataFolder)
        )
    }

    /// The helpers bundled with the app, and a folder for the one that updates itself.
    static func helpers(in dataFolder: URL) -> HelperInstallation {
        HelperInstallation(
            bundledFolder: Bundle.main.bundleURL.appending(path: "Contents/Helpers", directoryHint: .isDirectory),
            supportFolder: dataFolder.appending(path: "Helpers", directoryHint: .isDirectory)
        )
    }

    static func makeLibrary(in folder: URL) throws -> LibraryRepository {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let container = try LibraryStore.makeContainer(at: folder.appending(path: "Library.store"))
        return LibraryRepository(modelContainer: container)
    }
}
