import SwiftUI

struct TorrentDetailView: View {
    let hash: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var torrent: TorrentInfo?
    @State private var properties: TorrentProperties?
    @State private var files: [TorrentFile] = []
    @State private var trackers: [TorrentTracker] = []
    @State private var peers: [TorrentPeer] = []
    @State private var showDeleteConfirmation = false
    @State private var isLoading = true
    @State private var processingAction: ActionType? = nil
    @State private var lastAnnounceAt: Date? = nil
    @State private var loadError: String? = nil
    @State private var announceCooldown = false
    @State private var syncRid = 0
    @State private var pollCount = 0
    @State private var peersRid = 0
    @State private var showAdvancedSheet = false
    @State private var newLocation = ""
    @State private var newName = ""
    @State private var dlLimitStr = ""
    @State private var ulLimitStr = ""
    @State private var showFileSheet = false
    @State private var showTrackerSheet = false
    @State private var selectedFileIndices: Set<Int> = []

    enum ActionType {
        case pause, force, recheck, announce
    }

    private let dataService: TorrentDetailDataService

    init(hash: String) {
        self.hash = hash
        self.dataService = TorrentDetailDataService(hash: hash)
    }

    var body: some View {
        ZStack {
            if isLoading {
                DetailSkeleton()
                    .padding(20)
            } else if let err = loadError {
                errorStateView(err)
            } else if let torrent = torrent {
                ScrollView {
                    VStack(spacing: AppSpacing.xl) {
                        dashboardCard(torrent)

                        if torrent.statusBadge.isError && !torrent.errorString.isEmpty {
                            errorHint(torrent.errorString)
                        }

                        actionGrid(torrent)

                        transferSection(torrent)
                        if let props = properties {
                            infoSection(props)
                        }
                        timeSection(torrent, props: properties)

                        if !files.isEmpty {
                            filesSection
                        }

                        if !trackers.isEmpty {
                            trackersSection
                        }

                        if !peers.isEmpty {
                            peersSection
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, 20)
                }
                .refreshable { await manualRefresh() }
                .frame(maxWidth: horizontalSizeClass == .regular ? 640 : nil)
            }
        }
        .orbixBackground()
        .navigationTitle(OrbixStrings.navDetails)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    if let t = torrent {
                        newLocation = properties?.savePath ?? ""
                        newName = t.name
                        dlLimitStr = t.dlLimit > 0 ? "\(t.dlLimit / 1024)" : ""
                        ulLimitStr = t.upLimit > 0 ? "\(t.upLimit / 1024)" : ""
                    }
                    showAdvancedSheet = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(AppColors.accentPrimary)
                }
                .accessibilityLabel(OrbixStrings.navAdvancedControl)
            }
            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(AppColors.danger)
                }
                .accessibilityLabel(OrbixStrings.btnDelete)
            }
        }
        .alert(OrbixStrings.miscDeleteTorrentTitle, isPresented: $showDeleteConfirmation) {
            Button(OrbixStrings.btnDeleteTaskOnly, role: .destructive) { delete(false) }
            Button(OrbixStrings.btnDeleteTaskFiles, role: .destructive) { delete(true) }
            Button(OrbixStrings.btnCancel, role: .cancel) {}
        } message: {
            Text(OrbixStrings.infoDeleteConfirm)
        }
        .sheet(isPresented: $showAdvancedSheet) {
            TorrentDetailAdvancedSheet(
                hash: hash,
                newLocation: $newLocation,
                newName: $newName,
                dlLimitStr: $dlLimitStr,
                ulLimitStr: $ulLimitStr
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showFileSheet) {
            TorrentDetailFileSheet(
                hash: hash,
                files: files,
                selectedFileIndices: $selectedFileIndices
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showTrackerSheet) {
            TorrentDetailTrackerSheet(
                hash: hash,
                trackers: $trackers
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .task { await autoRefreshLoop() }
    }

    // MARK: - Dashboard Card

    @ViewBuilder
    private func dashboardCard(_ torrent: TorrentInfo) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: torrent.statusBadge.iconName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(torrent.statusBadge.statusColor)
                Text(torrent.statusBadge.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(torrent.statusBadge.statusColor)
                Spacer()
                if torrent.dlspeed > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 11, weight: .bold))
                        Text(formatSpeed(torrent.dlspeed))
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    }
                    .foregroundColor(AppColors.accentPrimary)
                } else if torrent.upspeed > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 11, weight: .bold))
                        Text(formatSpeed(torrent.upspeed))
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    }
                    .foregroundColor(AppColors.success)
                }
            }

            Text(torrent.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(3)

            HStack(alignment: .bottom) {
                Text("\(torrent.progressPercent)%")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(torrent.progressColor)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatBytes(torrent.downloaded))
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(AppColors.textPrimary)
                    Text("/ " + formatBytes(torrent.size))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppColors.hairlineDivider)
                    Capsule()
                        .fill(torrent.progressColor)
                        .frame(width: max(0, geometry.size.width * CGFloat(torrent.progress)))
                }
            }
            .frame(height: 4)
        }
        .padding(AppSpacing.lg)
        .orbixCard()
    }

    // MARK: - Action Grid

    private func actionGrid(_ torrent: TorrentInfo) -> some View {
        HStack(spacing: AppSpacing.md) {
            ActionTile(
                icon: torrent.statusBadge.isPaused ? "play.fill" : "pause.fill",
                label: torrent.statusBadge.isPaused ? OrbixStrings.btnStart : OrbixStrings.btnPause,
                color: torrent.statusBadge.isPaused ? AppColors.success : AppColors.warning,
                isLoading: processingAction == .pause,
                action: { performAction(.pause, torrent: torrent) }
            )
            ActionTile(
                icon: "bolt.fill",
                label: OrbixStrings.btnForce,
                color: AppColors.accentPrimary,
                isLoading: processingAction == .force,
                action: { performAction(.force, torrent: torrent) }
            )
            ActionTile(
                icon: "checkmark.shield.fill",
                label: OrbixStrings.btnRecheck,
                color: AppColors.accentPrimary,
                isLoading: processingAction == .recheck,
                action: { performAction(.recheck, torrent: torrent) }
            )
            ActionTile(
                icon: announceCooldown ? "clock.fill" : "antenna.radiowaves.left.and.right",
                label: announceCooldown ? OrbixStrings.btnWait : OrbixStrings.btnAnnounce,
                color: announceCooldown ? Color.secondary : AppColors.accentPrimary,
                isLoading: processingAction == .announce || announceCooldown,
                action: { performAction(.announce, torrent: torrent) }
            )
        }
    }

    // MARK: - Transfer Section

    private func transferSection(_ torrent: TorrentInfo) -> some View {
        VStack(spacing: 0) {
            SectionHeader(title: OrbixStrings.sectionTransfer)

            VStack(spacing: 0) {
                DetailRow(icon: "arrow.down.circle.fill", iconColor: AppColors.accentPrimary,
                          label: OrbixStrings.labelDownloadSpeed, value: formatSpeed(torrent.dlspeed), valueColor: AppColors.accentPrimary)
                HairlineDivider(leadingPadding: 44)
                DetailRow(icon: "arrow.up.circle.fill", iconColor: AppColors.success,
                          label: OrbixStrings.labelUploadSpeed, value: formatSpeed(torrent.upspeed), valueColor: AppColors.success)
                HairlineDivider(leadingPadding: 44)
                DetailRow(icon: "tray.and.arrow.down.fill", iconColor: .secondary,
                          label: OrbixStrings.labelDownloaded, value: formatBytes(torrent.downloaded))
                HairlineDivider(leadingPadding: 44)
                DetailRow(icon: "tray.and.arrow.up.fill", iconColor: .secondary,
                          label: OrbixStrings.labelUploaded, value: formatBytes(torrent.uploaded))
                HairlineDivider(leadingPadding: 44)
                DetailRow(icon: "chart.pie.fill", iconColor: .secondary,
                          label: OrbixStrings.labelRatio, value: String(format: "%.2f", torrent.ratio),
                          valueColor: torrent.ratio >= 1.0 ? AppColors.success : .secondary)
                if torrent.eta > 0 {
                    HairlineDivider(leadingPadding: 44)
                    DetailRow(icon: "timer", iconColor: .secondary,
                              label: OrbixStrings.labelETA, value: torrent.etaFormatted)
                }
                HairlineDivider(leadingPadding: 44)
                DetailRow(icon: "person.2.fill", iconColor: .secondary,
                          label: OrbixStrings.labelSeeds,
                          value: "\(String(torrent.numSeeds)) / \(String(torrent.numLeechs))")
            }
            .orbixCard()
        }
    }

    // MARK: - Info Section

    private func infoSection(_ props: TorrentProperties) -> some View {
        VStack(spacing: 0) {
            SectionHeader(title: OrbixStrings.sectionInfo)

            VStack(spacing: 0) {
                DetailRow(icon: "internaldrive.fill", iconColor: .secondary,
                          label: OrbixStrings.labelTotalSize, value: formatBytes(props.totalSize))
                HairlineDivider(leadingPadding: 44)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: AppSpacing.md) {
                        Image(systemName: "folder.fill")
                            .sfSymbolFrame()
                            .foregroundColor(.secondary)
                        Text(OrbixStrings.labelSavePath)
                            .font(.system(size: 15))
                            .foregroundColor(AppColors.textPrimary)
                        Spacer()
                        CopyButton(textToCopy: props.savePath)
                    }
                    Text(props.savePath)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                        .padding(.leading, IconLayout.sfSymbolSize + AppSpacing.md)
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.md)

                if !props.category.isEmpty {
                    HairlineDivider(leadingPadding: 44)
                    DetailRow(icon: "square.grid.2x2.fill", iconColor: .secondary,
                              label: OrbixStrings.labelCategory, value: props.category)
                }
                if !props.tags.isEmpty {
                    HairlineDivider(leadingPadding: 44)
                    DetailRow(icon: "tag.fill", iconColor: .secondary,
                              label: OrbixStrings.labelTags, value: props.tags)
                }

                HairlineDivider(leadingPadding: 44)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: AppSpacing.md) {
                        Image(systemName: "number.circle.fill")
                            .sfSymbolFrame()
                            .foregroundColor(.secondary)
                        Text(OrbixStrings.labelHash)
                            .font(.system(size: 15))
                            .foregroundColor(AppColors.textPrimary)
                        Spacer()
                        CopyButton(textToCopy: props.hash)
                    }
                    Text(props.hash)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(AppColors.textTertiary)
                        .padding(.leading, IconLayout.sfSymbolSize + AppSpacing.md)
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.md)
            }
            .orbixCard()
        }
    }

    // MARK: - Files Section

    private var filesSection: some View {
        VStack(spacing: 0) {
            HStack {
                SectionHeader(title: "\(OrbixStrings.miscAddModeFile) (\(files.count))")
                Spacer()
                Button {
                    showFileSheet = true
                } label: {
                    Text(OrbixStrings.btnManage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.accentPrimary)
                }
                .padding(.trailing, AppSpacing.lg)
            }

            VStack(spacing: 0) {
                ForEach(files.indices, id: \.self) { index in
                    let file = files[index]
                    VStack(alignment: .leading, spacing: 6) {
                        Text(file.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(2)

                        HStack {
                            Text(formatBytes(file.size))
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(AppColors.textSecondary)
                            Spacer()
                            Text("\(file.progressPercent)%")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(file.progress >= 1.0 ? AppColors.success : AppColors.accentPrimary)
                        }

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                                    .fill(AppColors.hairlineDivider)
                                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                                    .fill(file.progress >= 1.0 ? AppColors.success : AppColors.accentPrimary)
                                    .frame(width: max(0, geometry.size.width * CGFloat(file.progress)))
                            }
                        }
                        .frame(height: 3)
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.md)

                    if index < files.count - 1 {
                        HairlineDivider(leadingPadding: 44)
                    }
                }
            }
            .orbixCard()
        }
    }

    // MARK: - Time Section

    private func timeSection(_ torrent: TorrentInfo, props: TorrentProperties?) -> some View {
        let added = props?.addedOn ?? torrent.addedOn
        let completed = props?.completionOn ?? torrent.completionOn
        return VStack(spacing: 0) {
            SectionHeader(title: OrbixStrings.sectionTime)

            VStack(spacing: 0) {
                DetailRow(icon: "calendar.badge.plus", iconColor: .secondary,
                          label: OrbixStrings.labelAddTime, value: formatUnixTime(added))
                if completed > 0 {
                    HairlineDivider(leadingPadding: 44)
                    DetailRow(icon: "checkmark.seal.fill", iconColor: AppColors.success,
                              label: OrbixStrings.labelCompleteTime, value: formatUnixTime(completed))
                }
            }
            .orbixCard()
        }
    }

    // MARK: - Trackers Section

    private var trackersSection: some View {
        VStack(spacing: 0) {
            HStack {
                SectionHeader(title: String(format: OrbixStrings.labelTrackersCount, trackers.count))
                Spacer()
                Button {
                    showTrackerSheet = true
                } label: {
                    Text(OrbixStrings.btnManage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.accentPrimary)
                }
                .padding(.trailing, AppSpacing.lg)
            }

            VStack(spacing: 0) {
                ForEach(trackers.indices, id: \.self) { index in
                    let tracker = trackers[index]
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: AppSpacing.sm) {
                            Circle()
                                .fill(tracker.statusColor)
                                .frame(width: 8, height: 8)
                            Text(tracker.statusText)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(tracker.statusColor)
                            Spacer()
                        }
                        Text("\(OrbixStrings.miscSeedsPrefix)：\(tracker.numSeeds) • 下载：\(tracker.numLeeches)")
                            .caption()
                        Text(tracker.url)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(2)
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if index < trackers.count - 1 {
                        HairlineDivider(leadingPadding: 44)
                    }
                }
            }
            .orbixCard()
        }
    }

    // MARK: - Peers Section

    private var peersSection: some View {
        VStack(spacing: 0) {
            SectionHeader(title: String(format: OrbixStrings.labelPeersCount, peers.count))

            VStack(spacing: 0) {
                ForEach(peers.indices, id: \.self) { index in
                    let peer = peers[index]
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(peer.ip):\(String(peer.port))")
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundColor(AppColors.textPrimary)
                            if !peer.country.isEmpty {
                                Text(peer.country)
                                    .font(.system(size: 12))
                                    .foregroundColor(countryColor(peer.countryCode))
                            }
                            Spacer()
                            if peer.upSpeed > 0 {
                                Text("↑ \(formatSpeed(peer.upSpeed))")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(AppColors.success)
                            }
                            Text("\(peer.progressPercent)%")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(AppColors.textSecondary)
                        }
                        if !peer.client.isEmpty {
                            Text(peer.client)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(AppColors.textTertiary.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if index < peers.count - 1 {
                        HairlineDivider(leadingPadding: 44)
                    }
                }
            }
            .orbixCard()
        }
    }

    private func countryColor(_ code: String) -> Color {
        switch code.uppercased() {
        case "CN", "HK", "TW", "MO": return AppColors.danger
        case "JP": return AppColors.accentPrimary
        case "US", "GB", "CA", "AU": return AppColors.success
        case "KR": return AppColors.warning
        default: return .secondary
        }
    }

    // MARK: - Error Hint

    private func errorHint(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(AppColors.danger)
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColors.danger)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                .fill(AppColors.danger.opacity(0.1))
        )
    }

    // MARK: - Error State

    @ViewBuilder
    private func errorStateView(_ message: String) -> some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(AppColors.emptyStateIconColor)

            Text(OrbixStrings.errLoadFailed)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)

            Text(message)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(AppColors.emptyStateTextColor)
                .multilineTextAlignment(.center)

            Button(OrbixStrings.btnRetry) {
                loadError = nil
                isLoading = true
                Task { await manualRefresh() }
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, AppSpacing.xl)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppColors.accentPrimary)
            )
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.gridBackgroundGradient)
    }

    // MARK: - Tiered Refresh Strategy

    private func refreshInfoPeers() async {
        let result = await dataService.fetchHighFreq(syncRid: syncRid, peersRid: peersRid)
        await MainActor.run {
            if let t = result.torrent { self.torrent = t }
            self.syncRid = result.syncRid
            if !result.peers.isEmpty { self.peers = result.peers }
            self.peersRid = result.peersRid
            pollCount += 1
            loadError = nil
        }
    }

    private func refreshFilesTrackers() async {
        let result = await dataService.fetchLowFreq()
        if let f = result.files {
            await MainActor.run { self.files = f }
        }
        if let tr = result.trackers {
            await MainActor.run { self.trackers = tr }
        }
    }

    private func autoRefreshLoop() async {
        do {
            let initial = try await dataService.fetchInitial()
            await MainActor.run {
                self.torrent = initial.torrent; isLoading = false
                self.properties = initial.properties
                self.files = initial.files; self.trackers = initial.trackers
                self.peers = initial.peers; self.peersRid = initial.peersRid
            }
        } catch {
            await MainActor.run {
                isLoading = false
                loadError = OrbixStrings.errCantLoadTorrent
            }
            return
        }

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                while !Task.isCancelled {
                    do { try await Task.sleep(nanoseconds: 2_000_000_000) }
                    catch is CancellationError { break }
                    catch { break }
                    guard !Task.isCancelled else { break }
                    await refreshInfoPeers()
                }
            }
            group.addTask {
                while !Task.isCancelled {
                    do { try await Task.sleep(nanoseconds: 8_000_000_000) }
                    catch is CancellationError { break }
                    catch { break }
                    guard !Task.isCancelled else { break }
                    await refreshFilesTrackers()
                }
            }
        }
    }

    @Sendable private func manualRefresh() async {
        let data = await dataService.fetchAll()
        await MainActor.run {
            if let t = data.torrent {
                self.torrent = t; loadError = nil
            } else if self.torrent == nil {
                loadError = OrbixStrings.errCantLoadTorrent
            }
            if let p = data.properties { self.properties = p }
            self.files = data.files; self.trackers = data.trackers
            self.peers = data.peers; self.peersRid = data.peersRid
            self.syncRid = 0; isLoading = false
        }
    }

    private func performAction(_ type: ActionType, torrent: TorrentInfo) {
        guard processingAction == nil else { return }
        if type == .announce, announceCooldown { return }

        processingAction = type
        let oldState = torrent.state
        let oldDlspeed = torrent.dlspeed
        let oldUpspeed = torrent.upspeed
        let oldProgress = torrent.progress

        let action: TorrentDetailAction = {
            switch type {
            case .pause: return .pause(isPaused: torrent.statusBadge.isPaused)
            case .force: return .force
            case .recheck: return .recheck
            case .announce: return .announce
            }
        }()

        Task {
            do {
                try await dataService.performAction(action)

                if type == .announce {
                    lastAnnounceAt = Date()
                    announceCooldown = true
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        announceCooldown = false
                    }
                }

                AppHaptics.success()

                if let newTorrent = await dataService.pollAfterAction(
                    oldState: oldState, oldDlspeed: oldDlspeed,
                    oldUpspeed: oldUpspeed, oldProgress: oldProgress
                ) {
                    await MainActor.run { self.torrent = newTorrent }
                }

                let details = await dataService.fetchDetailsAfterAction()
                await MainActor.run {
                    if let p = details.properties { properties = p }
                    files = details.files; trackers = details.trackers
                    peers = details.peers; peersRid = details.peersRid
                }
            } catch {
                AppHaptics.error()
            }

            await MainActor.run { processingAction = nil }
        }
    }

    private func delete(_ deleteFiles: Bool) {
        Task {
            try? await QBitApi.shared.deleteTorrent(hash, deleteFiles: deleteFiles)
            dismiss()
        }
    }

    private func formatUnixTime(_ timestamp: Int64) -> String {
        guard timestamp > 0 else { return "-" }
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.setLocalizedDateFormatFromTemplate("yMMMMdjm")
        return fmt.string(from: date)
    }
}

// MARK: - Detail Skeleton

private struct DetailSkeleton: View {
    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            dashboardSkeleton
            actionsSkeleton
            sectionSkeleton
            sectionSkeleton
        }
    }

    private var dashboardSkeleton: some View {
        VStack(spacing: AppSpacing.md) {
            HStack {
                SkeletonBar(height: 14, width: 80)
                Spacer()
            }
            SkeletonBar(height: 20)
            HStack {
                SkeletonBar(height: 42, width: 80)
                Spacer()
                SkeletonBar(height: 14, width: 100)
            }
            SkeletonBar(height: 4)
        }
        .padding(AppSpacing.lg)
        .orbixCard()
    }

    private var actionsSkeleton: some View {
        HStack(spacing: AppSpacing.md) {
            ForEach(0..<4, id: \.self) { _ in
                VStack(spacing: AppSpacing.sm) {
                    SkeletonBar(height: 44, width: 44)
                    SkeletonBar(height: 12, width: 36)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var sectionSkeleton: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SkeletonBar(height: 14, width: 60)
                .padding(.leading, AppSpacing.lg)

            VStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { i in
                    HStack {
                        SkeletonBar(height: 28, width: 28)
                        SkeletonBar(height: 14, width: 80)
                        Spacer()
                        SkeletonBar(height: 14, width: 60)
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, 11)

                    if i < 2 {
                        Rectangle()
                            .fill(AppColors.hairlineDivider)
                            .frame(height: 0.5)
                            .padding(.leading, IconLayout.sfSymbolSize + AppSpacing.lg + AppSpacing.md)
                    }
                }
            }
            .orbixCard()
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        TorrentDetailView(hash: "demo")
    }
}
#endif
