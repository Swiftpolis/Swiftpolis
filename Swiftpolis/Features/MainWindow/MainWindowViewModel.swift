import Foundation
import Observation
import SwiftpolisDomain
import SwiftpolisPersistence

@Observable
final class MainWindowViewModel {
    enum State {
        case loading
        case loaded
        case failed(message: String)
    }

    private(set) var state = State.loading
    private(set) var categories: [CategorySummary] = []
    var selectedCategoryName = CategoryKind.allDownloadsName

    @ObservationIgnored private let makeLibrary: @Sendable () throws -> LibraryRepository

    init(makeLibrary: @escaping @Sendable () throws -> LibraryRepository) {
        self.makeLibrary = makeLibrary
    }

    func load() async {
        do {
            let library = try makeLibrary()
            try await library.prepareForLaunch()
            categories = try await library.categories()
            state = .loaded
        } catch {
            state = .failed(message: error.localizedDescription)
        }
    }
}
