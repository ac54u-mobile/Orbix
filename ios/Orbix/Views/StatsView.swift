import SwiftUI

struct StatsView: View {
    @State private var transfer: TransferInfo?
    @State private var torrents: [TorrentInfo] = []
    @State private var isLoading = true
    @Environment(\.scenePhase) private var scenePhase

    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.mainBg.ignoresSafeArea()

                if isLoading {
                    VStack(spacing: 12) {
                        SkeletonBar(height: 80)
                        SkeletonBar(height: 80)
                        SkeletonBar(height: 80)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                        Text(OrbixStrings.statsCurrSpeed).sectionHeader()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        heroSpeedCard

                        if transfer?.serverState != nil {
                            Text(OrbixStrings.statsVolume).sectionHeader()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        transferVolumeCard

                        if transfer?.serverState != nil {
                            Text(OrbixStrings.statsConnection).sectionHeader()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        connectionCard

                        if transfer?.serverState != nil {
                            Text(OrbixStrings.statsDisk).sectionHeader()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        diskCard

                            Text(OrbixStrings.statsOverview).sectionHeader()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            overviewCard

                            Color.clear.frame(height: 80)
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 20)
                    }
                }
            }
            .navigationTitle(OrbixStrings.navTransferStats)
            .onAppear { refresh() }
            .onReceive(timer) { _ in
                guard scenePhase == .active else { return }
                refresh()
            }
        }
    }

    // MARK: - Hero Speed Card
    private var heroSpeedCard: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(formattedHeroSpeed)
                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                    .foregroundColor(AppColors.accent)
                Text("B/s")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.tertiaryLabel)
            }

            HStack(spacing: 24) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(AppColors.accent)
                        .frame(width: 8, height: 8)
                    Text(formatSpeed(transfer?.dlInfoSpeed ?? 0))
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(AppColors.accent)
                    Text("↓")
                        .caption()
                }
                HStack(spacing: 4) {
                    Circle()
                        .fill(AppColors.success)
                        .frame(width: 8, height: 8)
                    Text(formatSpeed(transfer?.upInfoSpeed ?? 0))
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(AppColors.success)
                    Text("↑")
                        .caption()
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .fill(AppColors.card)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(formattedHeroSpeed) B/s")
    }

    // MARK: - Transfer Volume Card
    @ViewBuilder
    private var transferVolumeCard: some View {
        if let state = transfer?.serverState {
            VStack(spacing: 0) {
                statRow(OrbixStrings.statsSessionDL, value: formatBytes(transfer?.dlInfoData ?? 0))
                Divider().background(AppColors.separator)
                statRow(OrbixStrings.statsSessionUL, value: formatBytes(transfer?.upInfoData ?? 0))
                Divider().background(AppColors.separator)
                statRow(OrbixStrings.statsTotalDL, value: formatBytes(state.alltimeDl))
                Divider().background(AppColors.separator)
                statRow(OrbixStrings.statsTotalUL, value: formatBytes(state.alltimeUl))
                Divider().background(AppColors.separator)
                statRow(OrbixStrings.statsGlobalRatio, value: state.globalRatio ?? "-")
                Divider().background(AppColors.separator)
                statRow(OrbixStrings.statsWasted, value: formatBytes(state.totalWastedSession))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                    .fill(AppColors.card)
            )
        }
    }

    // MARK: - Connection Card
    @ViewBuilder
    private var connectionCard: some View {
        if let state = transfer?.serverState {
            VStack(spacing: 0) {
                connectionStatusRow(status: state.connectionStatus)
                Divider().background(AppColors.separator)
                statRow(OrbixStrings.statsDHT, value: "\(state.dhtNodes)")
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                    .fill(AppColors.card)
            )
        }
    }

    // MARK: - Disk Card
    @ViewBuilder
    private var diskCard: some View {
        if let state = transfer?.serverState {
            VStack(spacing: 0) {
                statRow(OrbixStrings.statsFreeSpace, value: formatBytes(state.freeSpaceOnDisk))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                    .fill(AppColors.card)
            )
        }
    }

    // MARK: - Overview Card
    private var overviewCard: some View {
        let dl = torrents.filter { $0.statusBadge == .downloading || $0.statusBadge == .metaDL }.count
        let up = torrents.filter { $0.statusBadge == .uploading || $0.statusBadge == .stalledUP }.count
        let paused = torrents.filter { $0.statusBadge.isPaused }.count
        let checking = torrents.filter { $0.statusBadge == .checkingDL || $0.statusBadge == .checkingUP }.count
        let errored = torrents.filter { $0.statusBadge.isError }.count

        return VStack(spacing: 0) {
            overviewRow("square.stack", OrbixStrings.statsTotal, torrents.count, AppColors.label)
            Divider().background(AppColors.separator)
            overviewRow("arrow.down.circle", OrbixStrings.statsDownloading, dl, AppColors.accent)
            Divider().background(AppColors.separator)
            overviewRow("arrow.up.circle", OrbixStrings.statsSeeding, up, AppColors.success)
            Divider().background(AppColors.separator)
            overviewRow("pause.circle", OrbixStrings.statsPaused, paused, AppColors.tertiaryLabel)
            Divider().background(AppColors.separator)
            overviewRow("arrow.triangle.2.circlepath", OrbixStrings.statsChecking, checking, AppColors.warning)
            Divider().background(AppColors.separator)
            overviewRow("exclamationmark.circle", OrbixStrings.statsError, errored, AppColors.danger)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .fill(AppColors.card)
        )
    }

    // MARK: - Row Helpers
    private func statRow(_ label: String, value: String) -> some View {
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
        .accessibilityLabel("\(label): \(value)")
    }

    private func connectionStatusRow(status: String) -> some View {
        HStack {
            Text(OrbixStrings.statsStatus)
                .font(.system(size: 14))
                .foregroundColor(AppColors.secondaryLabel)
            Spacer()
            HStack(spacing: 4) {
                Circle()
                    .fill(connectionColor(status))
                    .frame(width: 8, height: 8)
                Text(status.capitalized)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(connectionColor(status))
            }
        }
        .padding(.vertical, 10)
    }

    private func overviewRow(_ icon: String, _ label: String, _ count: Int, _ color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 24)
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(AppColors.secondaryLabel)
            Spacer()
            Text("\(count)")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(color)
        }
        .padding(.vertical, 10)
    }

    // MARK: - Data
    private var formattedHeroSpeed: String {
        let total = (transfer?.dlInfoSpeed ?? 0) + (transfer?.upInfoSpeed ?? 0)
        if total >= 1_000_000 { return String(format: "%.1f M", Double(total) / 1_000_000) }
        if total >= 1_000 { return String(format: "%.1f K", Double(total) / 1_000) }
        return "\(total)"
    }

    private func connectionColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "connected": return AppColors.success
        case "firewalled": return AppColors.warning
        default: return AppColors.danger
        }
    }

    private func refresh() {
        Task {
            do {
                let t = try await QBitApi.shared.getTransferInfo()
                let list = try await QBitApi.shared.getTorrents()
                await MainActor.run {
                    transfer = t
                    torrents = list
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
