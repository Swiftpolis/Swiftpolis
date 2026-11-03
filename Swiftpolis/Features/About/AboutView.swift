import AppKit
import SwiftUI

struct AboutView: View {
    @State private var document: BundledDocument?
    @Environment(\.openURL) private var openURL

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            Text("Swiftpolis").font(.title.bold())
            Text(version)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            Text("A native download manager for macOS.")
            Text("Based on [Persepolis Download Manager](\(ProjectLinks.persepolis.absoluteString)), by its developers and contributors.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Copyright © 2026 Amir Abravesh. Free software under the GNU General Public License, version 3.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("License") { document = .license }
                Button("Third-Party Notices") { document = .thirdPartyNotices }
            }
            if let page = ProjectLinks.page, let issues = ProjectLinks.issues {
                HStack {
                    Button("Source Code") { openURL(page) }
                    Button("Report an Issue") { openURL(issues) }
                }
            }
        }
        .padding(24)
        .frame(width: 400)
        .sheet(item: $document) { document in
            BundledDocumentView(document: document)
        }
    }
}

/// A text file that ships inside the app, as the licenses require.
enum BundledDocument: String, Identifiable {
    case license = "LICENSE"
    case thirdPartyNotices = "THIRD-PARTY-NOTICES.md"

    var id: Self { self }

    var text: String {
        Bundle.main.url(forResource: rawValue, withExtension: nil)
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) }
            ?? "This file is missing from the app."
    }
}

private struct BundledDocumentView: View {
    let document: BundledDocument
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                Text(document.text)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            HStack {
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 600, height: 480)
    }
}
