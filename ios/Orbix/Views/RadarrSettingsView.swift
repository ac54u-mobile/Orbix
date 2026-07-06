import SwiftUI

struct RadarrSettingsView: View {
    @State private var config = RadarrConfig.load()
    @State private var savedConfig = RadarrConfig.load()
    @State private var portText = ""
    @State private var isTesting = false
    @State private var testResult: TestOutcome?
    @State private var showSavedToast = false

    private enum TestOutcome {
        case success(version: String)
        case failure(message: String)
    }

    var body: some View {
        Form {
            Section {
                TextField(String(localized: "地址（IP 或域名）", comment: "Host"), text: $config.host)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                TextField(String(localized: "端口", comment: "Port"), text: $portText)
                    .keyboardType(.numberPad)

                Toggle("HTTPS", isOn: $config.https)
            } header: {
                Text(String(localized: "服务器", comment: "Server"))
            } footer: {
                Text(String(localized: "例如地址填 152.53.131.108，端口 7878", comment: "Radarr host example"))
            }

            Section {
                SecureField("API Key", text: $config.apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("API Key")
            } footer: {
                Text(String(localized: "在 Radarr 网页端 设置 → 通用 → 安全 中查看 API Key", comment: "Where to find API key"))
            }

            Section {
                Button {
                    testConnection()
                } label: {
                    HStack {
                        Label(String(localized: "测试连接", comment: "Test connection"), systemImage: "bolt.horizontal")
                        Spacer()
                        if isTesting {
                            ProgressView()
                        }
                    }
                }
                .disabled(isTesting || config.host.isEmpty || config.apiKey.isEmpty)

                if let result = testResult {
                    switch result {
                    case .success(let version):
                        Label(String(format: String(localized: "连接成功，Radarr v%@", comment: "Connected"), version), systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    case .failure(let message):
                        Label(message, systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .navigationTitle("Radarr")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(OrbixStrings.btnSave) {
                    save()
                    AppHaptics.success()
                    showSavedToast = true
                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        showSavedToast = false
                    }
                }
                .fontWeight(.semibold)
                .disabled(config == savedConfig)
            }
        }
        .toast(isPresented: $showSavedToast, type: .success, message: String(localized: "已保存", comment: "Saved"))
        .onAppear {
            portText = String(config.port)
        }
        .onChange(of: portText) { _, new in
            if let port = Int(new), port > 0 {
                config.port = port
            }
        }
    }

    private func save() {
        config.save()
        savedConfig = config
    }

    private func testConnection() {
        isTesting = true
        testResult = nil
        AppHaptics.light()
        let testConfig = config
        Task {
            do {
                let version = try await RadarrApi.shared.systemStatus(config: testConfig)
                await MainActor.run {
                    isTesting = false
                    testResult = .success(version: version)
                    AppHaptics.success()
                }
            } catch {
                await MainActor.run {
                    isTesting = false
                    testResult = .failure(message: error.localizedDescription)
                    AppHaptics.error()
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        RadarrSettingsView()
    }
}
#endif
