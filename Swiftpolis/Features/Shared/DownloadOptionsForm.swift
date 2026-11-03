import SwiftUI
import UniformTypeIdentifiers
import SwiftpolisDomain
import SwiftpolisEngines
import SwiftpolisServices

/// The options shared by the Add Link and Properties windows.
struct DownloadOptionsForm<General: View>: View {
    @Binding var draft: DownloadDraft
    let categories: [String]
    @ViewBuilder let general: General

    @State private var isChoosingFolder = false
    @State private var isChoosingCookies = false
    @State private var proxyMessage = ""

    var body: some View {
        TabView {
            Tab("General", systemImage: "link") { generalTab }
            Tab("Proxy", systemImage: "network") { proxyTab }
            Tab("Advanced", systemImage: "gearshape") { advancedTab }
        }
    }

    private var generalTab: some View {
        Form {
            general
            TextField("Link", text: $draft.link)
            Toggle("Change file name", isOn: $draft.changesName)
            TextField("File name", text: $draft.customName)
                .disabled(!draft.changesName)
            LabeledContent("Download folder") {
                HStack {
                    Text(draft.folder)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(draft.folder)
                    Button("Change") { isChoosingFolder = true }
                }
            }
            Stepper("Number of connections: \(draft.connections)", value: $draft.connections, in: 1...64)
            Picker("Add to", selection: $draft.category) {
                ForEach(categories, id: \.self) { Text($0) }
            }
        }
        .formStyle(.grouped)
        .fileImporter(isPresented: $isChoosingFolder, allowedContentTypes: [.folder]) { result in
            if case .success(let folder) = result { draft.folder = folder.path }
        }
    }

    private var proxyTab: some View {
        Form {
            Toggle("Use a proxy", isOn: $draft.usesProxy)
            Group {
                Picker("Type", selection: $draft.proxyKind) {
                    Text("HTTP").tag(ProxySettings.Kind.http)
                    Text("SOCKS5").tag(ProxySettings.Kind.socks5)
                }
                TextField("Host", text: $draft.proxyHost)
                TextField("Port", value: $draft.proxyPort, format: .number.grouping(.never))
                TextField("Username", text: $draft.proxyUser)
                SecureField("Password", text: $draft.proxyPassword)
            }
            .disabled(!draft.usesProxy)
            LabeledContent("System proxy") {
                HStack {
                    Text(proxyMessage).foregroundStyle(.secondary)
                    Button("Detect", action: detectProxy)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func detectProxy() {
        if let proxy = SystemProxy.detect() {
            draft.proxyHost = proxy.host
            draft.proxyPort = proxy.port
            draft.usesProxy = true
            proxyMessage = ""
        } else {
            draft.usesProxy = false
            proxyMessage = "No proxy detected!"
        }
    }

    private var advancedTab: some View {
        Form {
            Section("Login") {
                Toggle("This site needs a login", isOn: $draft.usesLogin)
                Group {
                    TextField("Username", text: $draft.loginUser)
                    SecureField("Password", text: $draft.loginPassword)
                }
                .disabled(!draft.usesLogin)
            }
            Section("Request") {
                TextField("Referrer", text: $draft.referer)
                TextField("User agent", text: $draft.userAgent)
                TextField("Headers", text: $draft.headers, axis: .vertical)
                    .lineLimit(2...4)
                LabeledContent("Cookie file") {
                    HStack {
                        Text(draft.cookieFilePath.isEmpty ? "None" : draft.cookieFilePath)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button("Choose") { isChoosingCookies = true }
                        if !draft.cookieFilePath.isEmpty {
                            Button("Clear") { draft.cookieFilePath = "" }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .fileImporter(isPresented: $isChoosingCookies, allowedContentTypes: [.item]) { result in
            if case .success(let file) = result { draft.cookieFilePath = file.path }
        }
    }
}
