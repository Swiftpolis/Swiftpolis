import SwiftUI
import SwiftpolisServices

struct SettingsView: View {
    @Bindable var model: MobileModel
    @Environment(\.dismiss) private var dismiss

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Use cellular data", isOn: $model.preferences.allowsCellularData)
                } footer: {
                    Text("Applies to downloads you start from now on.")
                }
                Section {
                    Toggle("Sort files into folders by type", isOn: $model.preferences.usesSubfolders)
                    Toggle("Check security certificates", isOn: $model.preferences.verifiesCertificates)
                } footer: {
                    Text("Your files are in the Files app, under On My iPad or On My iPhone, in Swiftpolis.")
                }
                Section("About") {
                    LabeledContent("Version", value: version)
                    Text("Based on Persepolis Download Manager, by its developers and contributors. Copyright © 2026 Amir Abravesh. Free software under the GNU General Public License, version 3.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    NavigationLink("License") { documentView("LICENSE", title: "License") }
                    NavigationLink("Third-Party Notices") {
                        documentView("THIRD-PARTY-NOTICES.md", title: "Third-Party Notices")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func documentView(_ file: String, title: String) -> some View {
        ScrollView {
            Text(
                Bundle.main.url(forResource: file, withExtension: nil)
                    .flatMap { try? String(contentsOf: $0, encoding: .utf8) }
                    ?? "This file is missing from the app."
            )
            .font(.system(.caption, design: .monospaced))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
