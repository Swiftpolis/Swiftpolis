import SwiftUI
import UniformTypeIdentifiers
import SwiftpolisDomain
import SwiftpolisEngines
import SwiftpolisServices

/// The options shared by the Add Link and Properties windows.
struct DownloadOptionsForm<General: View>: View {
    @Binding var draft: DownloadDraft
    let categories: [String]
    var createQueue: ((String) -> Void)?
    @ViewBuilder let general: General

    @State private var isChoosingFolder = false
    @State private var isChoosingCookies = false
    @State private var proxyMessage = ""
    @State private var isNamingQueue = false
    @State private var newQueueName = "queue"

    var body: some View {
        TabView {
            Tab("General", systemImage: "link") { generalTab }
            Tab("Schedule", systemImage: "clock") { scheduleTab }
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
            HStack {
                Picker("Add to", selection: $draft.category) {
                    ForEach(categories, id: \.self) { Text($0) }
                }
                if createQueue != nil {
                    Button("New Queue") { isNamingQueue = true }
                }
            }
        }
        .alert("Enter queue name:", isPresented: $isNamingQueue) {
            TextField("Queue", text: $newQueueName)
            Button("OK") { createQueue?(newQueueName) }
            Button("Cancel", role: .cancel) {}
        }
        .formStyle(.grouped)
        .fileImporter(isPresented: $isChoosingFolder, allowedContentTypes: [.folder]) { result in
            if case .success(let folder) = result { draft.folder = folder.path }
        }
    }

    private var scheduleTab: some View {
        Form {
            Section {
                Toggle("Start at", isOn: $draft.usesStartTime)
                ClockTimePicker("Start time", time: $draft.startTime)
                    .disabled(!draft.usesStartTime)
                Toggle("Stop at", isOn: $draft.usesEndTime)
                ClockTimePicker("End time", time: $draft.endTime)
                    .disabled(!draft.usesEndTime)
            } footer: {
                Text(draft.canHaveOwnTimes ? ScheduleNotes.text : "A queue's downloads run on the queue's own times.")
            }
            .disabled(!draft.canHaveOwnTimes)
        }
        .formStyle(.grouped)
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

/// Picks a time of day, for Start and End times.
struct ClockTimePicker: View {
    private let label: String
    @Binding private var time: ClockTime

    init(_ label: String, time: Binding<ClockTime>) {
        self.label = label
        _time = time
    }

    var body: some View {
        DatePicker(label, selection: dateBinding, displayedComponents: .hourAndMinute)
    }

    private var dateBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                if let new = ClockTime(hour: parts.hour ?? 0, minute: parts.minute ?? 0) { time = new }
            }
        )
    }
}

enum ScheduleNotes {
    static let short = "Times are forgotten if you quit, and the Mac has to be awake to start on time."
    static let text = "Times are forgotten if you quit Swiftpolis, and the Mac has to be awake to start on time. "
        + "If it's asleep, the download starts when it wakes, unless the end time has passed."
}

enum QueueNaming {
    static func message(for error: Error, name: String) -> String {
        switch error as? QueueNameError {
        case .alreadyExists: "\"\(name)\" already exists!"
        case .empty: "Enter a queue name."
        case nil: error.localizedDescription
        }
    }
}
