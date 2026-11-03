import Foundation

/// Where the project lives online.
enum ProjectLinks {
    /// The GitHub account that hosts Swiftpolis. The update check and the About window's links use it. With
    /// `nil`, the check says it isn't set up, and the links are left out.
    static let owner: String? = "Swiftpolis"

    static var repository: String? { owner.map { "\($0)/Swiftpolis" } }
    static var page: URL? { repository.flatMap { URL(string: "https://github.com/\($0)") } }
    static var issues: URL? { page?.appending(path: "issues") }

    static let persepolis = URL(string: "https://github.com/persepolisdm/persepolis")!
}
