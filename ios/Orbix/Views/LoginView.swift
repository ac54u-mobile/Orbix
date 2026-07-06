import SwiftUI

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss

    let server: ServerConfig?
    let onSave: (ServerConfig) -> Void

    @State private var name: String = ""
    @State private var host: String = ""
    @State private var port: String = "8080"
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var https: Bool = false
    @State private var showPassword: Bool = false

    @State private var isTesting = false
    @State private var testResult: ConnectResult?

    init(server: ServerConfig? = nil, onSave: @escaping (ServerConfig) -> Void) {
        self.server = server
        self.onSave = onSave
        _name = State(initialValue: server?.name ?? "")
        _host = State(initialValue: server?.host ?? "")
        _port = State(initialValue: "\(server?.port ?? 8080)")
        _username = State(initialValue: server?.username ?? "")
        _password = State(initialValue: server?.password ?? "")
        _https = State(initialValue: server?.https ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        GlowingLogo(size: 64)

                        VStack(spacing: 4) {
                            Text("Orbix")
                                .font(.title2.bold())
                            Text(OrbixStrings.infoConfigHint)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                Section(OrbixStrings.sectionServerInfo) {
                    LabeledContent(OrbixStrings.miscNameOptional) {
                        TextField(OrbixStrings.phServerName, text: $name)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent(OrbixStrings.miscHost) {
                        TextField(OrbixStrings.phHostAddress, text: $host)
                            .multilineTextAlignment(.trailing)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .keyboardType(.URL)
                    }
                    LabeledContent(OrbixStrings.miscPort) {
                        TextField(OrbixStrings.phPort, text: $port)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                    }
                }

                Section(OrbixStrings.sectionAuth) {
                    LabeledContent(OrbixStrings.miscUsername) {
                        TextField(OrbixStrings.phUsername, text: $username)
                            .multilineTextAlignment(.trailing)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    LabeledContent(OrbixStrings.miscPassword) {
                        HStack {
                            if showPassword {
                                TextField(OrbixStrings.phPassword, text: $password)
                                    .multilineTextAlignment(.trailing)
                            } else {
                                SecureField(OrbixStrings.phPassword, text: $password)
                                    .multilineTextAlignment(.trailing)
                            }
                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section {
                    Toggle(OrbixStrings.miscEnableHTTPS, isOn: $https)
                } footer: {
                    if https {
                        Text(OrbixStrings.infoSSLHint)
                    }
                }

                Section {
                    Button {
                        AppHaptics.light()
                        testConnection()
                    } label: {
                        HStack {
                            Spacer()
                            if isTesting {
                                ProgressView()
                            } else {
                                Text(OrbixStrings.btnTestConnection)
                            }
                            Spacer()
                        }
                    }
                    .disabled(isTesting || host.isEmpty)
                    if let result = testResult {
                        HStack {
                            Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                            Text(result.isSuccess ? OrbixStrings.miscConnectSuccess : result.message)
                                .font(.footnote)
                        }
                        .foregroundStyle(result.isSuccess ? Color.green : Color.red)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 4)
                    }
                } footer: {
                    Text(OrbixStrings.infoTestHint)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(server != nil ? OrbixStrings.navEditServer : OrbixStrings.navAddServer)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(OrbixStrings.btnCancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(OrbixStrings.btnSave) { save() }
                        .fontWeight(.semibold)
                        .disabled(host.isEmpty || username.isEmpty)
                }
            }
        }
    }

    private func testConnection() {
        let config = buildConfig()
        isTesting = true
        testResult = nil

        Task {
            await QBitApi.shared.setActiveServer(config)
            let result = await QBitApi.shared.connect()
            await MainActor.run {
                isTesting = false
                withAnimation(.spring) {
                    testResult = result
                }
                if result.isSuccess {
                    AppHaptics.success()
                } else {
                    AppHaptics.error()
                }
            }
        }
    }

    private func save() {
        AppHaptics.medium()
        let config = buildConfig()
        Task { await QBitApi.shared.upsertServer(config) }
        onSave(config)
        dismiss()
    }

    private func buildConfig() -> ServerConfig {
        ServerConfig(
            name: name.isEmpty ? host : name,
            host: host,
            port: Int(port) ?? 8080,
            username: username,
            password: password,
            https: https
        )
    }
}

#if DEBUG
#Preview {
    LoginView { _ in }
}
#endif
