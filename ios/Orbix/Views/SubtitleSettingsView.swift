import SwiftUI

struct SubtitleSettingsView: View {
    @State private var config = SubtitleServiceConfig.load()
    @State private var savedConfig = SubtitleServiceConfig.load()
    @State private var portText = ""
    @State private var isTesting = false
    @State private var testResult: TestOutcome?
    @State private var showSavedToast = false

    private enum TestOutcome {
        case success
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
            } header: {
                Text(String(localized: "服务器", comment: "Server"))
            } footer: {
                Text(String(localized: "运行在下载服务器上的字幕服务（server/subtitle），默认端口 8788", comment: ""))
            }

            Section {
                SecureField("API Key", text: $config.apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("API Key")
            } footer: {
                Text(String(localized: "服务器 /etc/orbix-subtitle.env 中 ORBIX_API_KEY 的值", comment: ""))
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
                    case .success:
                        Label(String(localized: "连接成功", comment: "Connected"), systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    case .failure(let message):
                        Label(message, systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .navigationTitle(String(localized: "字幕服务", comment: "Subtitle service"))
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
                try await SubtitleServerApi.shared.testConnection(config: testConfig)
                await MainActor.run {
                    isTesting = false
                    testResult = .success
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
        SubtitleSettingsView()
    }
}
#endif
