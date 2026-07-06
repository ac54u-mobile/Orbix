import SwiftUI

struct SettingsView: View {
    let onLogout: () -> Void

    @State private var appVersion: String = ""
    @State private var buildNumber: String = ""
    @State private var serverName: String = ""
    @State private var serverURL: String = ""
    @State private var serverVersion: String = ""
    @State private var username: String = ""
    @State private var serverOnline: Bool?
    @State private var serverHttps: Bool = false

    @State private var updateCheck: UpdateCheck?
    @State private var isCheckingUpdate = false
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0

    @EnvironmentObject private var appLock: AppLockService

    var body: some View {
        NavigationStack {
            List {
                serverProfileSection

                if appLock.isDeviceSupported {
                    Section(String(localized: "安全", comment: "Security")) {
                        appLockToggle
                    }
                }

                Section(String(localized: "更新", comment: "Update")) {
                    updateRow
                    if let release = updateCheck?.latest {
                        releaseRow(release)
                    }
                    if isDownloading {
                        downloadRow
                    }
                }

                Section(String(localized: "关于", comment: "About")) {
                    LabeledContent(String(localized: "版本", comment: "Version")) {
                        Text(appVersion).monospacedDigit()
                    }
                    LabeledContent(String(localized: "构建号", comment: "Build")) {
                        Text(buildNumber).monospacedDigit()
                    }
                }

                Section {
                    Button(role: .destructive) {
                        logout()
                    } label: {
                        Label(OrbixStrings.btnSwitchServer, systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(OrbixStrings.navSettings)
            .onAppear { loadInfo() }
        }
    }

    // MARK: - Server Profile

    private var serverProfileSection: some View {
        Section {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 48, height: 48)
                    Text(String(serverName.prefix(1).uppercased()))
                        .font(.system(.title2, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(serverName)
                            .font(.headline)
                        if serverHttps {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                    }

                    HStack(spacing: 4) {
                        Circle()
                            .fill(serverOnline == true ? Color.green : (serverOnline == false ? Color.red : Color(.tertiaryLabel)))
                            .frame(width: 7, height: 7)
                        Text(serverOnline == true ? String(localized: "在线", comment: "Online") :
                                serverOnline == false ? String(localized: "离线", comment: "Offline") :
                                String(localized: "检测中…", comment: "Checking"))
                            .font(.footnote)
                            .foregroundStyle(serverOnline == true ? Color.green : Color.secondary)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 4)

            LabeledContent(OrbixStrings.sectionAddress) {
                Text(serverURL)
                    .font(.system(.subheadline, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            if !serverVersion.isEmpty {
                LabeledContent(OrbixStrings.miscQBVersion) {
                    Text(serverVersion)
                        .font(.system(.subheadline, design: .monospaced))
                }
            }
            LabeledContent(OrbixStrings.sectionUser, value: username)
        }
        .contextMenu {
            if !serverURL.isEmpty {
                Button {
                    UIPasteboard.general.string = serverURL
                } label: {
                    Label(String(localized: "复制地址", comment: "Copy address"), systemImage: "doc.on.doc")
                }
            }
            Button(role: .destructive) {
                logout()
            } label: {
                Label(OrbixStrings.btnSwitchServer, systemImage: "rectangle.portrait.and.arrow.right")
            }
        }
    }

    // MARK: - Security
    private var appLockToggle: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(String(localized: "应用锁", comment: "App lock"), isOn: $appLock.isEnabled)

            if appLock.isEnabled {
                Text(String(localized: "切到后台 \(Int(AppConstants.lockGracePeriod)) 秒后自动锁定", comment: "Auto-lock hint"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Update
    private var updateRow: some View {
        Button {
            checkUpdate()
        } label: {
            HStack(spacing: 12) {
                Group {
                    if isCheckingUpdate {
                        ProgressView()
                    } else if let check = updateCheck, check.latest != nil {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundStyle(.orange)
                    } else if updateCheck?.error != nil {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundStyle(.red)
                    } else if updateCheck != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 26)

                VStack(alignment: .leading, spacing: 2) {
                    Text(updateStatusText)
                        .foregroundStyle(.primary)
                    if let detail = updateStatusDetail {
                        Text(detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .disabled(isCheckingUpdate)
    }

    private var updateStatusText: String {
        if isCheckingUpdate { return OrbixStrings.btnCheckUpdate }
        if updateCheck?.latest != nil { return OrbixStrings.miscUpdateAvailable }
        if updateCheck?.error != nil { return OrbixStrings.btnRetry }
        if updateCheck != nil { return OrbixStrings.btnCheckUpdate }
        return OrbixStrings.btnCheckUpdate
    }

    private var updateStatusDetail: String? {
        if isCheckingUpdate { return nil }
        if updateCheck?.latest != nil { return nil }
        if updateCheck?.error != nil { return nil }
        if updateCheck != nil { return OrbixStrings.msgUpToDate }
        return nil
    }

    private func releaseRow(_ release: AppRelease) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(release.version)
                    .font(.headline)
                Spacer()
                if let size = release.ipaSize {
                    Text(formatBytes(size))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color(.secondarySystemFill), in: Capsule())
                }
            }

            let cleanNotes = release.notes
                .replacingOccurrences(of: "\\[[^\\]]+\\]\\([^)]+\\)", with: "", options: .regularExpression)
                .replacingOccurrences(of: "https?://\\S+", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanNotes.isEmpty {
                Text(cleanNotes)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            Button {
                downloadUpdate(release)
            } label: {
                Text(isDownloading ? OrbixStrings.msgDownloadingDot : OrbixStrings.btnDownloadInstall)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isDownloading)
        }
        .padding(.vertical, 4)
    }

    private var downloadRow: some View {
        VStack(spacing: 6) {
            ProgressView(value: downloadProgress)
                .animation(.easeOut(duration: 0.3), value: downloadProgress)
            Text("\(min(99, Int(downloadProgress * 100)))%")
                .font(.caption.monospacedDigit().weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Data
    private func loadInfo() {
        appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"

        // 本地配置先展示，网络请求（qBit 版本、连接测试）后台补齐，页面不转圈
        Task {
            let config = await QBitApi.shared.loadSavedConfig()
            await MainActor.run {
                serverName = config?.name ?? "-"
                serverURL = config?.url ?? "-"
                username = config?.username ?? "-"
                serverHttps = config?.https ?? false
            }

            async let qbitVersion = try? QBitApi.shared.getAppVersion()
            async let testResult: CredentialsManager.TestResult? = {
                guard let cfg = config else { return nil }
                return await CredentialsManager.testConnection(
                    kind: .qBittorrent, host: cfg.host, port: cfg.port, https: cfg.https,
                    username: cfg.username, password: cfg.password
                )
            }()

            let (version, sR) = await (qbitVersion, testResult)
            await MainActor.run {
                serverVersion = version ?? ""
                serverOnline = sR?.isSuccess
            }
        }
    }

    private func logout() {
        Task {
            await QBitApi.shared.setActiveServer(ServerConfig(
                name: "", host: "", port: 0, username: "", password: "", https: false
            ))
        }
        onLogout()
    }

    private func checkUpdate() {
        isCheckingUpdate = true
        Task {
            let check = await UpdateService.shared.check(force: true)
            await MainActor.run {
                updateCheck = check
                isCheckingUpdate = false
            }
        }
    }

    private func downloadUpdate(_ release: AppRelease) {
        isDownloading = true
        downloadProgress = 0
        Task {
            do {
                let url = try await UpdateService.shared.downloadIpa(release) { progress in
                    Task { @MainActor in downloadProgress = progress }
                }
                await MainActor.run {
                    isDownloading = false
                    shareIpa(url)
                }
            } catch {
                await MainActor.run { isDownloading = false }
            }
        }
    }

    private func shareIpa(_ url: URL) {
        guard let win = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let w = win.windows.first, let root = w.rootViewController else { return }
        root.present(UIActivityViewController(activityItems: [url], applicationActivities: nil), animated: true)
    }
}

#if DEBUG
#Preview {
    SettingsView(onLogout: {})
}
#endif
