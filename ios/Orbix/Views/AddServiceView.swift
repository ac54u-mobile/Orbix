import SwiftUI

struct AddServiceView: View {
    @Environment(\.dismiss) private var dismiss

    let existing: ServiceCredential?
    let onSave: (ServiceCredential) -> Void

    @State private var kind: ServiceKind
    @State private var name: String = ""
    @State private var host: String = ""
    @State private var port: String = ""
    @State private var apiKey: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var https: Bool = false
    @State private var showApiKey: Bool = false
    @State private var showPassword: Bool = false
    @State private var isTesting = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    init(existing: ServiceCredential? = nil, onSave: @escaping (ServiceCredential) -> Void) {
        self.existing = existing
        self.onSave = onSave
        let cred = existing
        _kind = State(initialValue: cred?.kind ?? .qBittorrent)
        _name = State(initialValue: cred?.name ?? "")
        _host = State(initialValue: cred?.host ?? "")
        _port = State(initialValue: cred != nil ? "\(cred!.port)" : "")
        _apiKey = State(initialValue: cred?.apiKey ?? "")
        _username = State(initialValue: cred?.username ?? "")
        _password = State(initialValue: cred?.password ?? "")
        _https = State(initialValue: cred?.https ?? false)
    }

    private var defaultPort: String { "8080" }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker(OrbixStrings.sectionServiceType, selection: $kind) {
                        ForEach(ServiceKind.allCases, id: \.self) { k in
                            HStack(spacing: 6) {
                                Image(systemName: k.icon)
                                Text(k.rawValue)
                            }
                            .tag(k)
                        }
                    }
                    .onChange(of: kind) { _, _ in
                        if port.isEmpty { port = defaultPort }
                    }
                }

                Section(OrbixStrings.sectionConnection) {
                    LabeledContent(OrbixStrings.sectionName) {
                        TextField(OrbixStrings.phOptional, text: $name)
                            .multilineTextAlignment(.trailing)
                    }

                    LabeledContent(OrbixStrings.sectionHost) {
                        TextField(OrbixStrings.phIP, text: $host)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                    }

                    LabeledContent(OrbixStrings.miscPort) {
                        TextField(defaultPort, text: $port)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                    }

                    Toggle(OrbixStrings.labelHTTPS, isOn: $https)
                }

                if kind == .qBittorrent {
                    Section(OrbixStrings.sectionAuth) {
                        LabeledContent(OrbixStrings.miscUsername) {
                            TextField(OrbixStrings.phUsername, text: $username)
                                .multilineTextAlignment(.trailing)
                                .autocapitalization(.none)
                        }
                        LabeledContent(OrbixStrings.miscPassword) {
                            HStack {
                                Group {
                                    if showPassword {
                                        TextField("", text: $password)
                                    } else {
                                        SecureField("", text: $password)
                                    }
                                }
                                .multilineTextAlignment(.trailing)
                                Button {
                                    showPassword.toggle()
                                } label: {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } else {
                    Section {
                        LabeledContent(OrbixStrings.labelAPIKey) {
                            HStack {
                                Group {
                                    if showApiKey {
                                        TextField("", text: $apiKey)
                                    } else {
                                        SecureField("", text: $apiKey)
                                    }
                                }
                                .multilineTextAlignment(.trailing)
                                Button {
                                    showApiKey.toggle()
                                } label: {
                                    Image(systemName: showApiKey ? "eye.slash" : "eye")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } header: {
                        Text(OrbixStrings.sectionAuth)
                    } footer: {
                        Text(String(format: OrbixStrings.infoAPIKeyHint, kind.rawValue))
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle(existing != nil ? OrbixStrings.navEditService : OrbixStrings.navAddService)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(OrbixStrings.btnCancel) { dismiss() }
                        .disabled(isTesting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isTesting {
                        ProgressView()
                    } else {
                        Button(OrbixStrings.btnConnect) { Task { await testAndSave() } }
                            .fontWeight(.semibold)
                            .disabled(host.isEmpty)
                    }
                }
            }
            .alert(OrbixStrings.msgConnTest, isPresented: $showAlert) {
                Button(OrbixStrings.btnOK, role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    private func testAndSave() async {
        guard !host.isEmpty else { return }
        let portValue = Int(port) ?? (https ? 443 : 80)
        isTesting = true

        let result = await CredentialsManager.testConnection(
            kind: kind, host: host, port: portValue, https: https,
            apiKey: apiKey, username: username, password: password
        )

        if result.isSuccess {
            isTesting = false
            saveCredential(port: portValue)
            await MainActor.run { dismiss() }
        } else {
            await MainActor.run {
                isTesting = false
                alertMessage = result.message
                showAlert = true
            }
        }
    }

    private func saveCredential(port portValue: Int) {
        let cleanHost = host
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        var cred = ServiceCredential(
            kind: kind, name: name.isEmpty ? kind.rawValue : name,
            host: cleanHost, port: portValue, https: https,
            apiKey: apiKey, username: username, password: password
        )
        if let existing = existing {
            cred = ServiceCredential(
                kind: kind, name: name.isEmpty ? existing.name : name,
                host: cleanHost, port: portValue, https: https,
                apiKey: apiKey.isEmpty ? existing.apiKey : apiKey,
                username: username, password: password
            )
        }
        onSave(cred)
    }
}

#if DEBUG
#Preview {
    AddServiceView(onSave: { _ in })
}
#endif
