import SwiftUI

struct StatsView: View {
    @State private var transfer: TransferInfo?
    @State private var serverState: ServerState?
    @State private var torrents: [TorrentInfo] = []
    @State private var isLoading = true
    @State private var serverVersion: String = ""
    @State private var refreshSuppressed = false
    @State private var firstLoad = true
    @Environment(\.scenePhase) private var scenePhase

    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            Group {
                if firstLoad {
                    ProgressView()
                        .controlSize(.large)
                } else {
                    List {
                        speedSection
                        historySection
                        sessionSection
                        serverInfoSection
                        torrentStatusSection
                        serverSection
                    }
                    .listStyle(.insetGrouped)
                    .transaction { t in
                        if !firstLoad && !isLoading {
                            t.disablesAnimations = true
                        }
                    }
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

    // MARK: - Speed

    private var speedSection: some View {
        Section(String(localized: "当前速度", comment: "Current speed")) {
            statRow(icon: "arrow.down", color: .blue,
                    label: String(localized: "下载速度", comment: "Download speed"),
                    value: transfer.flatMap { formatSpeed($0.dlInfoSpeed) } ?? "0 B/s")
            statRow(icon: "arrow.up", color: .green,
                    label: String(localized: "上传速度", comment: "Upload speed"),
                    value: transfer.flatMap { formatSpeed($0.upInfoSpeed) } ?? "0 B/s")
        }
    }

    // MARK: - Server
    private var serverSection: some View {
        Section(String(localized: "服务器", comment: "Server")) {
            statRow(icon: "server.rack", color: .blue,
                    label: "qBittorrent",
                    value: serverVersion.isEmpty ? "—" : serverVersion)
        }
    }

    // MARK: - History Stats
    @ViewBuilder
    private var historySection: some View {
        if let s = serverState {
            Section(String(localized: "历史统计", comment: "History stats")) {
                statRow(icon: "arrow.down.circle.fill", color: .blue,
                        label: String(localized: "总下载量", comment: "Total downloaded"),
                        value: formatBytes(s.alltimeDl))
                statRow(icon: "arrow.up.circle.fill", color: .green,
                        label: String(localized: "总上传量", comment: "Total uploaded"),
                        value: formatBytes(s.alltimeUl))
                statRow(icon: "chart.line.uptrend.xyaxis", color: .orange,
                        label: String(localized: "分享率", comment: "Ratio"),
                        value: s.globalRatio ?? "—")
            }
        }
    }

    // MARK: - Current Session
    private var sessionSection: some View {
        let t = transfer
        return Section(String(localized: "当前会话", comment: "Current session")) {
            statRow(icon: "tray.and.arrow.down", color: .blue,
                    label: String(localized: "已下载", comment: "Downloaded"),
                    value: t.flatMap { formatBytes($0.dlInfoData) } ?? "—")
            statRow(icon: "tray.and.arrow.up", color: .green,
                    label: String(localized: "已上传", comment: "Uploaded"),
                    value: t.flatMap { formatBytes($0.upInfoData) } ?? "—")
        }
    }

    // MARK: - Server Info
    private var serverInfoSection: some View {
        Section(String(localized: "服务器信息", comment: "Server info")) {
            statRow(icon: "internaldrive", color: .blue,
                    label: String(localized: "可用磁盘空间", comment: "Free disk space"),
                    value: freeSpaceText)
            statRow(icon: "point.3.connected.trianglepath.dotted",
                    color: connectionColor(connectionStatus),
                    label: String(localized: "总连接数", comment: "Total connections"),
                    value: serverState.map { "\($0.totalPeerConnections)" } ?? "—")
            statRow(icon: "hourglass", color: .orange,
                    label: String(localized: "队列IO任务", comment: "Queue IO jobs"),
                    value: serverState.map { "\($0.queuedIoJobs)" } ?? "—")
            statRow(icon: "network", color: .blue,
                    label: String(localized: "DHT 节点", comment: "DHT nodes"),
                    value: dhtNodesText)
            statRow(icon: "antenna.radiowaves.left.and.right",
                    color: connectionColor(connectionStatus),
                    label: String(localized: "连接状态", comment: "Connection status"),
                    value: connectionStatus.isEmpty ? "—" : connectionStatusText(connectionStatus))
        }
    }

    // MARK: - Torrent Status
    private var torrentStatusSection: some View {
        let dl = torrents.filter { $0.statusBadge == .downloading || $0.statusBadge == .metaDL }.count
        let up = torrents.filter { $0.statusBadge == .uploading || $0.statusBadge == .stalledUP }.count
        let paused = torrents.filter { $0.statusBadge.isPaused }.count
        let errored = torrents.filter { $0.statusBadge.isError }.count

        return Section(String(localized: "种子状态", comment: "Torrent status")) {
            statRow(icon: "square.stack", color: .primary,
                    label: String(localized: "种子总数", comment: "Total torrents"),
                    value: "\(torrents.count)")
            statRow(icon: "arrow.down.circle", color: .blue,
                    label: OrbixStrings.statsDownloading,
                    value: "\(dl)")
            statRow(icon: "arrow.up.circle", color: .green,
                    label: OrbixStrings.statsSeeding,
                    value: "\(up)")
            statRow(icon: "pause.circle", color: .secondary,
                    label: OrbixStrings.statsPaused,
                    value: "\(paused)")
            statRow(icon: "exclamationmark.circle", color: .red,
                    label: OrbixStrings.statsError,
                    value: "\(errored)")
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

    private func statRow(icon: String, color: Color, label: String, value: String) -> some View {
        LabeledContent {
            Text(value)
                .monospacedDigit()
        } label: {
            Label {
                Text(label)
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(color)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }

    private func connectionColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "connected": return .green
        case "firewalled": return .orange
        default: return .red
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
                    firstLoad = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    firstLoad = false
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    StatsView()
}
#endif
