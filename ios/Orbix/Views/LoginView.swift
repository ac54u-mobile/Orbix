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
                    VStack(spacing: 16) {
                        GlowingLogo(size: 64)

                        VStack(spacing: 6) {
                            Text("Orbix")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            Text("配置 qBittorrent 连接")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                Section {
                    FormRow(icon: "tag.fill", title: "名称（可选）") {
                        TextField("例如：家庭 NAS", text: $name)
                    }
                    FormRow(icon: "server.rack", title: "主机地址") {
                        TextField("IP 或域名", text: $host)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .keyboardType(.URL)
                    }
                    FormRow(icon: "network", title: "端口") {
                        TextField("8080", text: $port)
                            .keyboardType(.numberPad)
                    }
                } header: {
                    Text("服务器信息")
                }

                Section {
                    FormRow(icon: "person.fill", title: "用户名") {
                        TextField("admin", text: $username)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }

                    FormRow(icon: "lock.fill", title: "密码") {
                        HStack {
                            if showPassword {
                                TextField("输入密码", text: $password)
                            } else {
                                SecureField("输入密码", text: $password)
                            }
                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text("认证")
                }

                Section {
                    HStack {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(.secondary)
                            .frame(width: 28, alignment: .leading)
                        Toggle("启用 HTTPS", isOn: $https)
                            .tint(AppColors.accent)
                    }
                } footer: {
                    if https {
                        Text("确保你的 qBittorrent 已配置 SSL 证书")
                    }
                }

                Section {
                    Button {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        testConnection()
                    } label: {
                        HStack {
                            Spacer()
                            if isTesting {
                                ProgressView()
                                    .tint(AppColors.accent)
                            } else {
                                Text("测试连接")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            Spacer()
                        }
                    }
                    .disabled(isTesting || host.isEmpty)
                    if let result = testResult {
                        HStack {
                            Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(result.isSuccess ? .green : .red)
                            Text(result.isSuccess ? "连接成功" : result.message)
                                .font(.system(size: 14))
                                .foregroundColor(result.isSuccess ? .green : .red)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 4)
                    }
                } footer: {
                    Text("测试将尝试使用当前配置连接到 qBittorrent")
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(AppColors.mainBg.ignoresSafeArea())
            .navigationTitle(server != nil ? "编辑服务器" : "添加服务器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .font(.system(size: 17, weight: .bold))
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
                testResult = result
            }
        }
    }

    private func save() {
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

private struct FormRow<Content: View>: View {
    let icon: String
    let title: String
    let content: Content

    init(icon: String, title: String, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.title = title
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .frame(width: 24, alignment: .center)

            VStack(alignment: .leading, spacing: 0) {
                content
                    .font(.system(size: 16))
            }
        }
        .padding(.vertical, 2)
    }
}
