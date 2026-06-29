import SwiftUI

struct SettingsView: View {
    let onLogout: () -> Void

    @State private var appVersion: String = ""
    @State private var serverName: String = ""
    @State private var serverURL: String = ""
    @State private var serverVersion: String = ""
    @State private var username: String = ""
    @State private var isLoading = true

    @State private var updateCheck: UpdateCheck?
    @State private var isCheckingUpdate = false
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0

    @EnvironmentObject private var appLock: AppLockService
    @ObservedObject private var creds = CredentialsManager.shared
    @State private var showAddService = false
    @State private var editingCred: ServiceCredential?

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.mainBg.ignoresSafeArea()

                if isLoading {
                    VStack(spacing: 12) {
                        SkeletonBar(height: 80)
                        SkeletonBar(height: 56)
                        SkeletonBar(height: 72)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            Text(OrbixStrings.sectionServer).sectionHeader()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            serverCard

                            Text(OrbixStrings.sectionSecurity).sectionHeader()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            securityCard

                            Text(OrbixStrings.sectionServices).sectionHeader()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            servicesCard

                            Text(OrbixStrings.sectionUpdate).sectionHeader()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            updateCard

                            Color.clear.frame(height: 80)
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 20)
                    }
                }
            }
            .navigationTitle(OrbixStrings.navSettings)
            .sheet(isPresented: $showAddService) {
                AddServiceView(existing: editingCred) { cred in
                    creds.save(cred)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .onAppear { loadInfo() }
        }
    }

    // MARK: - Server Card
    private var serverCard: some View {
        VStack(spacing: 0) {
            serverRow(label: OrbixStrings.sectionName, value: serverName)
            Divider().background(AppColors.separator)

            HStack {
                Text(OrbixStrings.sectionAddress)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.secondaryLabel)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: serverURL.hasPrefix("https") ? "lock.fill" : "lock.open")
                        .font(.caption2)
                        .foregroundColor(serverURL.hasPrefix("https") ? AppColors.success : AppColors.secondaryLabel)
                    Text(serverURL)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(AppColors.label)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)

            if !serverVersion.isEmpty {
                Divider().background(AppColors.separator)
                serverRow(label: OrbixStrings.miscQBVersion, value: serverVersion)
            }

            Divider().background(AppColors.separator)
            serverRow(label: OrbixStrings.sectionUser, value: username)

            Divider().background(AppColors.separator)

            Button {
                logout()
            } label: {
                HStack {
                    Spacer()
                    Text(OrbixStrings.btnSwitchServer)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.danger)
                    Spacer()
                }
                .padding(.vertical, 10)
            }
            .accessibilityLabel(OrbixStrings.btnSwitchServer)
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.card)
        )
    }

    // MARK: - Security Card
    @ViewBuilder
    private var securityCard: some View {
        if appLock.isDeviceSupported {
            VStack(spacing: 0) {
                Toggle(isOn: $appLock.isEnabled) {
                    HStack(spacing: 8) {
                        Image(systemName: appLock.hasFaceID ? "faceid" : "touchid")
                            .font(.system(size: 18))
                            .foregroundColor(AppColors.accent)
                        Text(appLock.hasFaceID ? "Face ID" : OrbixStrings.miscBiometric)
                            .font(.system(size: 15))
                            .foregroundColor(AppColors.label)
                    }
                }
                .tint(AppColors.accent)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                if appLock.isEnabled {
                    Divider().background(AppColors.separator)
                    Text(OrbixStrings.infoAppLockHint)
                        .caption()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppColors.card)
            )
        }
    }

    // MARK: - Services Card
    private var servicesCard: some View {
        VStack(spacing: 0) {
            ForEach(creds.allCredentials) { cred in
                Button {
                    editingCred = cred
                    showAddService = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: cred.kind.icon)
                            .foregroundColor(AppColors.accent)
                            .font(.system(size: 16))
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cred.name)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppColors.label)
                            Text(cred.kind.rawValue + " · \(cred.host):\(cred.port)")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(AppColors.tertiaryLabel)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.tertiaryLabel)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }

                if cred.id != creds.allCredentials.last?.id {
                    Divider().background(AppColors.separator)
                }
            }

            Button {
                editingCred = nil
                showAddService = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.accent)
                    Text(OrbixStrings.navAddService).font(.system(size: 14)).foregroundColor(AppColors.accent)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.card)
        )
    }

    // MARK: - Update Card
    private var updateCard: some View {
        VStack(spacing: 0) {
            serverRow(label: OrbixStrings.sectionVersion, value: "v\(appVersion)")

            Divider().background(AppColors.separator)

            Button {
                checkUpdate()
            } label: {
                HStack {
                    Text(OrbixStrings.btnCheckUpdate)
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.secondaryLabel)
                    Spacer()
                    if isCheckingUpdate {
                        ProgressView()
                            .tint(AppColors.accent)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColors.tertiaryLabel)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
            }
            .accessibilityLabel(OrbixStrings.btnCheckUpdate)
            .disabled(isCheckingUpdate)

            if let check = updateCheck {
                Divider().background(AppColors.separator)

                if let release = check.latest {
                    updateReleaseCard(release)
                        .padding(12)
                } else if let error = check.error {
                    Text("\(OrbixStrings.errCheckFailed): \(error)")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.success)
                        Text(OrbixStrings.msgUpToDate)
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.success)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
            }

            if isDownloading {
                Divider().background(AppColors.separator)
                VStack(spacing: 8) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2).fill(AppColors.separator)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(AppColors.accent)
                                .frame(width: geo.size.width * downloadProgress)
                        }
                    }
                    .frame(height: 4)
                    HStack {
                        Text(OrbixStrings.msgDownloading)
                            .caption()
                        Spacer()
                        Text("\(min(99, Int(downloadProgress * 100)))%")
                            .caption(AppColors.accent)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.card)
        )
    }

    // MARK: - Sub-Components
    private func serverRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(AppColors.secondaryLabel)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(AppColors.label)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .accessibilityLabel("\(label): \(value)")
    }

    private func updateReleaseCard(_ release: AppRelease) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(release.version)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.accent)
                Spacer()
                if let size = release.ipaSize {
                        Text(formatBytes(size))
                            .caption()
                }
            }

            let cleanNotes = release.notes
                .replacingOccurrences(of: "\\[[^\\]]+\\]\\([^)]+\\)", with: "", options: .regularExpression)
                .replacingOccurrences(of: "https?://\\S+", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanNotes.isEmpty {
                Text(cleanNotes)
                    .sectionHeader()
                    .lineLimit(4)
            }

            Button {
                downloadUpdate(release)
            } label: {
                HStack {
                    Spacer()
                    Text(isDownloading ? OrbixStrings.msgDownloadingDot : OrbixStrings.btnDownloadInstall)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.label)
                    Spacer()
                }
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppColors.accent)
                )
            }
            .accessibilityLabel(OrbixStrings.btnDownloadInstall)
            .disabled(isDownloading)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.accentSoftBg)
        )
    }

    // MARK: - Data
    private func loadInfo() {
        Task {
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
            let config = await QBitApi.shared.loadSavedConfig()
            let qbitVersion = try? await QBitApi.shared.getAppVersion()

            await MainActor.run {
                appVersion = version
                serverName = config?.name ?? "-"
                serverURL = config?.url ?? "-"
                username = config?.username ?? "-"
                serverVersion = qbitVersion ?? ""
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
                    Task { @MainActor in
                        downloadProgress = progress
                    }
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
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let root = window.rootViewController else { return }

        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        root.present(vc, animated: true)
    }
}

#if DEBUG
#Preview {
    SettingsView(onLogout: {})
}
#endif
