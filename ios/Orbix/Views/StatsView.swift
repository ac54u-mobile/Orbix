import SwiftUI

struct StatsView: View {
    @State private var transfer: TransferInfo?
    @State private var serverState: ServerState?
    @State private var torrents: [TorrentInfo] = []
    @State private var isLoading = true
    @State private var serverVersion: String = ""
    @State private var refreshSuppressed = false
    @Environment(\.scenePhase) private var scenePhase

    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundGradient
                    .ignoresSafeArea()

                if isLoading {
                    SkeletonList(count: 5)
                        .padding(.top, AppSpacing.lg)
                } else {
                    List {
                        speedBannerSection
                        historySection
                        sessionSection
                        serverInfoSection
                        torrentStatusSection
                        serverSection
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                }
            }
            .navigationTitle(OrbixStrings.navTransferStats)
            .onAppear { refresh() }
            .onReceive(timer) { _ in
                guard !refreshSuppressed else { return }
                refresh()
            }
            .onChange(of: scenePhase) { _, phase in
                refreshSuppressed = phase != .active
            }
        }
    }

    // MARK: - Speed Banner
    private var speedBannerSection: some View {
        Section {
            HStack(spacing: 12) {
                speedCard(
                    icon: "arrow.down",
                    color: AppColors.accentPrimary,
                    label: String(localized: "下载速度", comment: "Download speed"),
                    value: transfer.flatMap { formatSpeed($0.dlInfoSpeed) } ?? "0 B/s"
                )
                speedCard(
                    icon: "arrow.up",
                    color: AppColors.success,
                    label: String(localized: "上传速度", comment: "Upload speed"),
                    value: transfer.flatMap { formatSpeed($0.upInfoSpeed) } ?? "0 B/s"
                )
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowSeparator(.hidden)
        }
    }

    private func speedCard(icon: String, color: Color, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .monoValue(AppColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(label)
                    .caption(AppColors.textSecondary)
            }
            Spacer()
        }
        .padding(12)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .frame(maxWidth: .infinity)
    }

    // MARK: - Server
    private var serverSection: some View {
        Section {
            statRow(icon: "server.rack", color: AppColors.accentPrimary,
                    label: "qBittorrent",
                    value: serverVersion.isEmpty ? "—" : serverVersion)
            .listRowBackground(Color.clear)
        } header: {
            sectionHeaderText(String(localized: "服务器", comment: "Server"))
        }
    }

    // MARK: - History Stats
    @ViewBuilder
    private var historySection: some View {
        if let s = serverState {
            Section {
                statRow(icon: "arrow.down.circle.fill", color: AppColors.accentPrimary,
                        label: String(localized: "总下载量", comment: "Total downloaded"),
                        value: formatBytes(s.alltimeDl))
                    .listRowBackground(Color.clear)

                statRow(icon: "arrow.up.circle.fill", color: AppColors.success,
                        label: String(localized: "总上传量", comment: "Total uploaded"),
                        value: formatBytes(s.alltimeUl))
                    .listRowBackground(Color.clear)

                statRow(icon: "chart.line.uptrend.xyaxis", color: AppColors.warning,
                        label: String(localized: "分享率", comment: "Ratio"),
                        value: s.globalRatio ?? "—")
                    .listRowBackground(Color.clear)
            } header: {
                sectionHeaderText(String(localized: "历史统计", comment: "History stats"))
            }
        }
    }

    // MARK: - Current Session
    private var sessionSection: some View {
        let t = transfer
        Section {
            statRow(icon: "tray.and.arrow.down", color: AppColors.accentPrimary.opacity(0.7),
                    label: String(localized: "已下载", comment: "Downloaded"),
                    value: t.flatMap { formatBytes($0.dlInfoData) } ?? "—")
                .listRowBackground(Color.clear)

            statRow(icon: "tray.and.arrow.up", color: AppColors.success.opacity(0.7),
                    label: String(localized: "已上传", comment: "Uploaded"),
                    value: t.flatMap { formatBytes($0.upInfoData) } ?? "—")
                .listRowBackground(Color.clear)
        } header: {
            sectionHeaderText(String(localized: "当前会话", comment: "Current session"))
        }
    }

    // MARK: - Server Info
    private var serverInfoSection: some View {
        Section {
            statRow(icon: "internaldrive", color: AppColors.accentPrimary,
                    label: String(localized: "可用磁盘空间", comment: "Free disk space"),
                    value: freeSpaceText)
                .listRowBackground(Color.clear)

            statRow(icon: "point.3.connected.trianglepath.dotted",
                    color: connectionColor(connectionStatus),
                    label: String(localized: "总连接数", comment: "Total connections"),
                    value: serverState.map { "\($0.totalPeerConnections)" } ?? "—")
                .listRowBackground(Color.clear)

            statRow(icon: "hourglass", color: AppColors.warning,
                    label: String(localized: "队列IO任务", comment: "Queue IO jobs"),
                    value: serverState.map { "\($0.queuedIoJobs)" } ?? "—")
                .listRowBackground(Color.clear)

            statRow(icon: "network", color: AppColors.accentPrimary.opacity(0.6),
                    label: String(localized: "DHT 节点", comment: "DHT nodes"),
                    value: dhtNodesText)
                .listRowBackground(Color.clear)

            statRow(icon: "antenna.radiowaves.left.and.right",
                    color: connectionColor(connectionStatus),
                    label: String(localized: "连接状态", comment: "Connection status"),
                    value: connectionStatus.isEmpty ? "—" : connectionStatusText(connectionStatus))
                .listRowBackground(Color.clear)
        } header: {
            sectionHeaderText(String(localized: "服务器信息", comment: "Server info"))
        }
    }

    // MARK: - Torrent Status
    private var torrentStatusSection: some View {
        let dl = torrents.filter { $0.statusBadge == .downloading || $0.statusBadge == .metaDL }.count
        let up = torrents.filter { $0.statusBadge == .uploading || $0.statusBadge == .stalledUP }.count
        let paused = torrents.filter { $0.statusBadge.isPaused }.count
        let errored = torrents.filter { $0.statusBadge.isError }.count

        Section {
            statRow(icon: "square.stack", color: .primary,
                    label: String(localized: "种子总数", comment: "Total torrents"),
                    value: "\(torrents.count)")
                .listRowBackground(Color.clear)

            statRow(icon: "arrow.down.circle", color: AppColors.accentPrimary,
                    label: OrbixStrings.statsDownloading,
                    value: "\(dl)")
                .listRowBackground(Color.clear)

            statRow(icon: "arrow.up.circle", color: AppColors.success,
                    label: OrbixStrings.statsSeeding,
                    value: "\(up)")
                .listRowBackground(Color.clear)

            statRow(icon: "pause.circle", color: AppColors.textTertiary,
                    label: OrbixStrings.statsPaused,
                    value: "\(paused)")
                .listRowBackground(Color.clear)

            statRow(icon: "exclamationmark.circle", color: AppColors.danger,
                    label: OrbixStrings.statsError,
                    value: "\(errored)")
                .listRowBackground(Color.clear)
        } header: {
            sectionHeaderText(String(localized: "种子状态", comment: "Torrent status"))
        }
    }

    // MARK: - Computed Values
    private var freeSpaceText: String {
        if let s = serverState { return formatBytes(s.freeSpaceOnDisk) }
        if let t = transfer, let v = t.freeSpaceOnDisk { return formatBytes(v) }
        return "—"
    }

    private var dhtNodesText: String {
        if let s = serverState { return "\(s.dhtNodes)" }
        if let t = transfer, let v = t.dhtNodes { return "\(v)" }
        return "—"
    }

    private var connectionStatus: String {
        if let s = serverState, !s.connectionStatus.isEmpty { return s.connectionStatus }
        if let t = transfer, let v = t.connectionStatus, !v.isEmpty { return v }
        return ""
    }

    // MARK: - Helpers
    private func sectionHeaderText(_ text: String) -> some View {
        Text(text)
            .font(AppTypography.caption())
            .foregroundColor(AppColors.textSecondary)
    }

    private func statRow(icon: String, color: Color, label: String, value: String, monospaced: Bool = false) -> some View {
        HStack(spacing: StatsViewConfig.elementSpacing) {
            Image(systemName: icon)
                .font(AppTypography.body())
                .foregroundColor(color)
                .frame(width: 28)
            Text(label)
                .bodyFont(AppColors.textSecondary)
            Spacer()
            Text(value)
                .font(monospaced ? AppTypography.monoValue() : AppTypography.body())
                .foregroundColor(AppColors.textPrimary)
        }
        .frame(minHeight: StatsViewConfig.listRowHeight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }

    private func connectionColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "connected": return AppColors.success
        case "firewalled": return AppColors.warning
        default: return AppColors.danger
        }
    }

    private func connectionStatusText(_ status: String) -> String {
        switch status.lowercased() {
        case "connected": return String(localized: "已连接", comment: "Connected")
        case "firewalled": return String(localized: "防火墙", comment: "Firewalled")
        default: return String(localized: "未连接", comment: "Disconnected")
        }
    }

    // MARK: - Data
    private func refresh() {
        Task {
            do {
                async let tTask = QBitApi.shared.getTransferInfo()
                async let sTask = QBitApi.shared.syncMainData(rid: 0)
                async let lTask = QBitApi.shared.getTorrents()
                async let vTask = QBitApi.shared.getAppVersion()

                let t = try await tTask
                let sync = try? await sTask
                let list = try await lTask
                let ver = try? await vTask

                await MainActor.run {
                    transfer = t
                    serverState = t?.serverState ?? sync?.serverState
                    torrents = list
                    serverVersion = ver ?? ""
                    isLoading = false
                }
            } catch {
                await MainActor.run { isLoading = false }
            }
        }
    }
}

#if DEBUG
#Preview {
    StatsView()
}
#endif
