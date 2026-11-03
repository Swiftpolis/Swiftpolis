import Observation
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers
import SwiftpolisServices

@Observable
final class PreferencesViewModel {
    private let model: AppModel
    private(set) var startsAtLogin = SMAppService.mainApp.status == .enabled
    private(set) var loginItemError: String?

    init(model: AppModel) {
        self.model = model
    }

    var preferences: Preferences {
        get { model.preferences }
        set { model.preferences = newValue }
    }

    func setStartsAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginItemError = nil
        } catch {
            loginItemError = error.localizedDescription
        }
        startsAtLogin = SMAppService.mainApp.status == .enabled
    }

    func restoreDownloadDefaults() {
        let defaults = Preferences()
        preferences.maxTries = defaults.maxTries
        preferences.retryWaitSeconds = defaults.retryWaitSeconds
        preferences.timeoutSeconds = defaults.timeoutSeconds
        preferences.connections = defaults.connections
        preferences.chunkSizeKiB = defaults.chunkSizeKiB
        preferences.queueWaitHours = defaults.queueWaitHours
        preferences.queueWaitMinutes = defaults.queueWaitMinutes
        preferences.verifiesCertificates = defaults.verifiesCertificates
    }
}

struct PreferencesView: View {
    @State private var viewModel: PreferencesViewModel
    @State private var isChoosingFolder = false

    init(model: AppModel) {
        _viewModel = State(initialValue: PreferencesViewModel(model: model))
    }

    var body: some View {
        TabView {
            Tab("Download Options", systemImage: "arrow.down.circle") { downloadTab }
            Tab("Save As", systemImage: "folder") { saveTab }
            Tab("Notifications", systemImage: "bell") { notificationsTab }
            Tab("Behaviour", systemImage: "gearshape") { behaviourTab }
        }
        .frame(width: 520, height: 460)
    }

    private var downloadTab: some View {
        Form {
            Stepper("Number of tries: \(viewModel.preferences.maxTries)", value: $viewModel.preferences.maxTries, in: 0...100)
            Stepper("Wait period between retries (seconds): \(viewModel.preferences.retryWaitSeconds)", value: $viewModel.preferences.retryWaitSeconds, in: 0...600)
            Stepper("Timeout (seconds): \(viewModel.preferences.timeoutSeconds)", value: $viewModel.preferences.timeoutSeconds, in: 1...600)
            Stepper("Number of connections: \(viewModel.preferences.connections)", value: $viewModel.preferences.connections, in: 1...64)
            Stepper("Chunk size (KiB): \(viewModel.preferences.chunkSizeKiB)", value: $viewModel.preferences.chunkSizeKiB, in: 10...10_000, step: 10)
            Stepper("Wait between queue items (hours): \(viewModel.preferences.queueWaitHours)", value: $viewModel.preferences.queueWaitHours, in: 0...23)
            Stepper("Wait between queue items (minutes): \(viewModel.preferences.queueWaitMinutes)", value: $viewModel.preferences.queueWaitMinutes, in: 0...59)
            Toggle("Verify servers' certificates", isOn: $viewModel.preferences.verifiesCertificates)
            Button("Defaults") { viewModel.restoreDownloadDefaults() }
        }
        .formStyle(.grouped)
    }

    private var saveTab: some View {
        Form {
            LabeledContent("Download folder") {
                HStack {
                    Text(viewModel.preferences.downloadFolder)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Button("Change") { isChoosingFolder = true }
                }
            }
            Toggle("Create subfolders for Audios, Videos, Documents, Compressed and Others", isOn: $viewModel.preferences.usesSubfolders)
            Stepper(
                "Links from a browser to open in Video Finder at once: \(viewModel.preferences.videoFinderMaxLinks)",
                value: $viewModel.preferences.videoFinderMaxLinks,
                in: 0...100
            )
        }
        .formStyle(.grouped)
        .fileImporter(isPresented: $isChoosingFolder, allowedContentTypes: [.folder]) { result in
            if case .success(let folder) = result { viewModel.preferences.downloadFolder = folder.path }
        }
    }

    private var notificationsTab: some View {
        Form {
            Toggle("Play notification sounds", isOn: $viewModel.preferences.playsSounds)
            LabeledContent("Volume") {
                Slider(
                    value: Binding(
                        get: { Double(viewModel.preferences.soundVolumePercent) },
                        set: { viewModel.preferences.soundVolumePercent = Int($0) }
                    ),
                    in: 0...100
                )
            }
            .disabled(!viewModel.preferences.playsSounds)
        }
        .formStyle(.grouped)
    }

    private var behaviourTab: some View {
        Form {
            Toggle("Show the progress window", isOn: $viewModel.preferences.showsProgressWindow)
            Toggle("Show a window when a download finishes", isOn: $viewModel.preferences.showsAfterDownloadDialog)
            Toggle("Show in the menu bar", isOn: $viewModel.preferences.showsMenuBarItem)
            Toggle("Keep the Dock icon when no windows are open", isOn: $viewModel.preferences.keepsDockIconWithoutWindows)
            Toggle("Keep running when the window closes", isOn: $viewModel.preferences.hidesWindowOnClose)
            Toggle("Keep the system awake while downloading", isOn: $viewModel.preferences.keepsSystemAwake)
            Toggle("Start links from the browser straight away", isOn: $viewModel.preferences.startsBrowserRequestsImmediately)
            Toggle("Check the clipboard for copied links", isOn: $viewModel.preferences.checksClipboard)
            Toggle(
                "Open at login",
                isOn: Binding(get: { viewModel.startsAtLogin }, set: { viewModel.setStartsAtLogin($0) })
            )
            if let error = viewModel.loginItemError {
                Text(error).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
