import Foundation
import SwiftpolisPersistence
import SwiftpolisServices

/// Builds the objects the app shares. This is the only place that knows where things are stored.
nonisolated enum AppDependencies {
    struct Environment {
        let dataFolder: URL
        let preferences: PreferencesStore
        let secrets: any SecretStore
    }

    static func environment() -> Environment {
        #if DEBUG
        if let debug = DebugAutomation.environment() { return debug }
        #endif
        return Environment(
            dataFolder: URL.applicationSupportDirectory.appending(path: "Swiftpolis", directoryHint: .isDirectory),
            preferences: PreferencesStore(),
            secrets: KeychainSecretStore()
        )
    }

    static func makeLibrary(in folder: URL) throws -> LibraryRepository {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let container = try LibraryStore.makeContainer(at: folder.appending(path: "Library.store"))
        return LibraryRepository(modelContainer: container)
    }
}
