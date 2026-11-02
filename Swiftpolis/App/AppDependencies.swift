import Foundation
import SwiftpolisPersistence

/// Builds the objects the app shares. This is the only place that knows where the store lives.
nonisolated enum AppDependencies {
    static func makeLibrary() throws -> LibraryRepository {
        let folder = URL.applicationSupportDirectory.appending(path: "Swiftpolis", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let container = try LibraryStore.makeContainer(at: folder.appending(path: "Library.store"))
        return LibraryRepository(modelContainer: container)
    }
}
