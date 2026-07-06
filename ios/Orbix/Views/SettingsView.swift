import SwiftUI

struct SettingsView: View {
    let onLogout: () -> Void

    @State private var appVersion: String = ""
    @State private var buildNumber: String = ""
    @State private var serverName: String = ""
    @State private var serverURL: String = ""
    @State private var serverVersion: String = ""
    @State private var username: String = ""
    @State private var isLoading = true
    @State private var serverOnline: Bool?
    @State private var serverHttps: Bool = false

    @State private var updateCheck: UpdateCheck?
    @State private var isCheckingUpdate = false
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0

    @EnvironmentObject private var appLock: AppLockService

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundGradient.ignoresSafeArea()

                if isLoading {
                    SkeletonList(count: 4)
                        .padding(.top, AppSpacing.lg)
                } else {
                    ScrollView {
                        VStack(spacing: AppSpacing.lg) {
                            serverProfileCard

                            if appLock.isDeviceSupported {
                                settingsSection(title: String(localized: "安全", comment: "Security")) {
                                    appLockToggle
                                }
                            }

                            settingsSection(title: String(localized: "更新", comment: "Update")) {
                                updateRow
                                if let release = updateCheck?.latest {
                                    releaseCard(release)
                                }
                                if isDownloading {
                                    downloadBar
                                }
                            }

                            settingsSection(title: String(localized: "关于", comment: "About")) {
                                aboutRow(icon: "info.circle", label: String(localized: "版本", comment: "Version"), value: appVersion)
                                aboutRow(icon: "number", label: String(localized: "构建号", comment: "Build"), value: buildNumber)
                            }
                        }
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.vertical, AppSpacing.lg)
                    }
                }
            }
            .navigationTitle(OrbixStrings.navSettings)
            .onAppear { loadInfo() }
        }
    }

    // Glass card section helper
    private func settingsSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: SettingsConfig.itemContentSpacing) {
            Text(title)
                .caption(AppColors.textSecondary)
            content()
        }
        .padding(AppSpacing.lg)
        .liquidGlass(.regular)
    }

    // MARK: - Server Profile Card (Glass)
    private var serverProfileCard: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppColors.accentPrimary)
                        .frame(width: 48, height: 48)
                    Text(String(serverName.prefix(1).uppercased()))
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(serverName)
                            .titleSmall()
                        if serverHttps {
                            Image(systemName: "lock.fill")
                                .tagCaption(AppColors.success)
                        }
                    }

                    HStack(spacing: 4) {
                        Circle()
                            .fill(serverOnline == true ? AppColors.success : (serverOnline == false ? AppColors.danger : AppColors.textTertiary))
                            .frame(width: 7, height: 7)
                        Text(serverOnline == true ? String(localized: "在线", comment: "Online") :
                                serverOnline == false ? String(localized: "离线", comment: "Offline") :
                                String(localized: "检测中…", comment: "Checking"))
                            .descriptionSmall(serverOnline == true ? AppColors.success : AppColors.textSecondary)
                    }
                }

                Spacer()
            }

            HairlineDivider()

            VStack(spacing: 0) {
                settingDetailRow(label: OrbixStrings.sectionAddress, value: serverURL, monospaced: true)
                HairlineDivider()
                if !serverVersion.isEmpty {
                    settingDetailRow(label: OrbixStrings.miscQBVersion, value: serverVersion, monospaced: true)
                    HairlineDivider()
                }
                settingDetailRow(label: OrbixStrings.sectionUser, value: username)
            }
        }
        .padding(AppSpacing.lg)
        .liquidGlass(.regular)
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
            Toggle(isOn: $appLock.isEnabled) {
                Text(String(localized: "应用锁", comment: "App lock"))
                    .bodyFont()
            }
            .tint(AppColors.accentPrimary)

            if appLock.isEnabled {
                Text(String(localized: "切到后台 \(Int(AppConstants.lockGracePeriod)) 秒后自动锁定", comment: "Auto-lock hint"))
                    .descriptionSmall()
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
                        ProgressView().scaleEffect(0.8)
                    } else if let check = updateCheck, check.latest != nil {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(AppColors.warning)
                    } else if updateCheck?.error != nil {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(AppColors.danger)
                    } else if updateCheck != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppColors.success)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                .font(AppTypography.body())
                .frame(width: 26)

                VStack(alignment: .leading, spacing: 2) {
                    Text(updateStatusText)
                        .bodyFont()
                    if let detail = updateStatusDetail {
                        Text(detail)
                            .descriptionSmall()
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .iconSymbol(AppColors.textTertiary)
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

    private func releaseCard(_ release: AppRelease) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text(release.version)
                    .titleSmall()
                Spacer()
                if let size = release.ipaSize {
                    Text(formatBytes(size))
                        .caption(AppColors.textSecondary)
                        .padding(.horizontal, AppSpacing.sm).padding(.vertical, 3)
                        .background(Capsule().fill(Color(.secondarySystemFill)))
                }
            }

            let cleanNotes = release.notes
                .replacingOccurrences(of: "\\[[^\\]]+\\]\\([^)]+\\)", with: "", options: .regularExpression)
                .replacingOccurrences(of: "https?://\\S+", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanNotes.isEmpty {
                Text(cleanNotes)
                    .descriptionSmall()
                    .lineLimit(3)
            }

            Button {
                downloadUpdate(release)
            } label: {
                Text(isDownloading ? OrbixStrings.msgDownloadingDot : OrbixStrings.btnDownloadInstall)
                    .font(AppTypography.filterLabel())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.accentPrimary))
            }
            .disabled(isDownloading)
        }
    }

    private var downloadBar: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                Capsule()
                    .fill(AppColors.accentPrimary)
                    .frame(width: max(4, geo.size.width * downloadProgress))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Capsule().fill(AppColors.separator))
                    .animation(.easeOut(duration: 0.3), value: downloadProgress)
            }
            .frame(height: 4)
            Text("\(min(99, Int(downloadProgress * 100)))%")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(AppColors.accentPrimary)
        }
    }

    // Detail row for server card
    private func settingDetailRow(label: String, value: String, monospaced: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(AppTypography.body())
                .foregroundColor(AppColors.textPrimary)
            Spacer()
            Text(value)
                .font(monospaced ? AppTypography.monoValue() : AppTypography.body())
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.vertical, AppSpacing.sm)
    }

    // MARK: - About
    private func aboutRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(AppTypography.body())
                .foregroundColor(AppColors.textTertiary)
                .frame(width: 26)
            Text(label)
                .bodyFont()
            Spacer()
            Text(value)
                .monoValue(AppColors.textSecondary)
        }
    }
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(AppColors.textTertiary)
                .frame(width: 26)
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .font(.system(size: 15, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Data
    private func loadInfo() {
        Task {
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
            let config = await QBitApi.shared.loadSavedConfig()
            let qbitVersion = try? await QBitApi.shared.getAppVersion()

            let configForTest = config
            let sR = await {
                guard let cfg = configForTest else { return nil as CredentialsManager.TestResult? }
                return await CredentialsManager.testConnection(
                    kind: .qBittorrent, host: cfg.host, port: cfg.port, https: cfg.https,
                    username: cfg.username, password: cfg.password
                )
            }()

            await MainActor.run {
                appVersion = version
                buildNumber = build
                serverName = config?.name ?? "-"
                serverURL = config?.url ?? "-"
                username = config?.username ?? "-"
                serverVersion = qbitVersion ?? ""
                serverHttps = config?.https ?? false
                serverOnline = sR?.isSuccess
                isLoading = false
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
            let check = await UpdateService.shared.check()
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
