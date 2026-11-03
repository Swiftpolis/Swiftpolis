import SwiftUI
import SwiftpolisServices

/// One place to add one link or a hundred: type them, or paste whatever a site copied.
struct AddLinksView: View {
    @State private var viewModel: AddLinksViewModel
    @State private var isNamingQueue = false
    @State private var newQueueName = ""
    @Environment(\.dismiss) private var dismiss

    init(model: MobileModel, text: String, category: String) {
        _viewModel = State(initialValue: AddLinksViewModel(model: model, text: text, category: category))
    }

    var body: some View {
        NavigationStack {
            Form {
                linksSection
                if !viewModel.draft.items.isEmpty {
                    foundSection
                    optionsSection
                }
            }
            .navigationTitle("Add Links")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .task { await viewModel.load() }
            .onChange(of: viewModel.hasSharedLinks, initial: true) { viewModel.takeSharedLinks() }
            .alert("New Queue", isPresented: $isNamingQueue) {
                TextField("Name", text: $newQueueName)
                Button("Create") {
                    let name = newQueueName
                    newQueueName = ""
                    Task { await viewModel.createQueue(named: name) }
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert(
                "Couldn't add them",
                isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.clearError() } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var linksSection: some View {
        Section {
            TextEditor(text: $viewModel.text)
                .frame(minHeight: 100)
                .font(.system(.footnote, design: .monospaced))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
            PasteButton(payloadType: String.self) { texts in
                let pasted = texts.joined(separator: "\n")
                viewModel.text = viewModel.text.isEmpty ? pasted : viewModel.text + "\n" + pasted
            }
        } header: {
            Text("Links")
        } footer: {
            Text("One link, or a whole list. Lines that aren't links are left out.")
        }
    }

    private var foundSection: some View {
        Section {
            ForEach(viewModel.draft.items) { item in
                Toggle(isOn: Binding(
                    get: { item.isSelected },
                    set: { viewModel.setSelected($0, id: item.id) }
                )) {
                    Text(item.shownName)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
            }
        } header: {
            HStack {
                Text("\(viewModel.draft.items.count) found")
                Spacer()
                Button("All") { viewModel.setAllSelected(true) }
                Button("None") { viewModel.setAllSelected(false) }
            }
        }
    }

    private var optionsSection: some View {
        Section("Options") {
            Picker("Add to", selection: $viewModel.category) {
                ForEach(viewModel.categories, id: \.self) { Text($0) }
            }
            Button("New Queue") { isNamingQueue = true }
            Toggle("This site needs a login", isOn: $viewModel.usesLogin)
            if viewModel.usesLogin {
                TextField("Username", text: $viewModel.loginUser)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Password", text: $viewModel.loginPassword)
                    .textContentType(.password)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .secondaryAction) {
            Button("Add Only") { submit(startsThem: false) }
                .disabled(!viewModel.draft.hasSelection)
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Start") { submit(startsThem: true) }
                .disabled(!viewModel.draft.hasSelection)
                .keyboardShortcut(.defaultAction)
        }
    }

    private func submit(startsThem: Bool) {
        Task {
            if await viewModel.add(startsThem: startsThem) { dismiss() }
        }
    }
}
