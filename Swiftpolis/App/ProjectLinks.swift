import Foundation

/// Where the project lives online.
enum ProjectLinks {
    /// The GitHub account that hosts Swiftpolis. Until this is filled in, the update check says it isn't
    /// set up, and the About window leaves out the project's links.
    static let owner: String? = nil

    static var repository: String? { owner.map { "\($0)/Swiftpolis" } }
    static var page: URL? { repository.flatMap { URL(string: "https://github.com/\($0)") } }
    static var issues: URL? { page?.appending(path: "issues") }

    static let persepolis = URL(string: "https://github.com/persepolisdm/persepolis")!
}
