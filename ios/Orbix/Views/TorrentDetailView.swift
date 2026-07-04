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
            AppColors.backgroundGradient.ignoresSafeArea()

            if isLoading {
                VStack(spacing: 16) {
                    SkeletonBar(height: 140)
                    SkeletonBar(height: 80)
                    SkeletonBar(height: 200)
                }
                .padding(20)
                .frame(maxWidth: horizontalSizeClass == .regular ? 640 : nil)
            } else if let err = loadError {
                errorStateView(err)
            } else if let torrent = torrent {
                ScrollView {
                    VStack(spacing: 20) {
                        dashboardCard(torrent)

                        if torrent.statusBadge.isError && !torrent.errorString.isEmpty {
                            errorHint(torrent.errorString)
                        }

                        actionGrid(torrent)

                        VStack(spacing: 16) {
                            transferSection(torrent)
                            if let props = properties {
                                infoSection(props)
                            }
                            timeSection(torrent, props: properties)
                        }

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
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
                .refreshable {
                    await manualRefresh()
                }
                .frame(maxWidth: horizontalSizeClass == .regular ? 640 : nil)
            }
        }
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
                        .foregroundColor(AppColors.accent)
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
            Button(OrbixStrings.btnDeleteTaskOnly, role: .destructive) {
                delete(false)
            }
            Button(OrbixStrings.btnDeleteTaskFiles, role: .destructive) {
                delete(true)
            }
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

    @ViewBuilder
    private func dashboardCard(_ torrent: TorrentInfo) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Status badge row
            HStack(spacing: 8) {
                Image(systemName: torrent.statusBadge.iconName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(torrent.statusBadge.statusColor)
                Text(torrent.statusBadge.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(torrent.statusBadge.statusColor)
                Spacer()
                if torrent.dlspeed > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 11, weight: .bold))
                        Text(formatSpeed(torrent.dlspeed))
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    }
                    .foregroundColor(AppColors.accent)
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
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(3)

            VStack(spacing: 8) {
                HStack {
                    Text("\(torrent.progressPercent)%")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(torrent.progressColor)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatBytes(torrent.downloaded))
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(.primary)
                        Text("/ " + formatBytes(torrent.size))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(.systemFill))
                        Capsule()
                            .fill(torrent.progressColor)
                            .frame(width: max(0, geometry.size.width * CGFloat(torrent.progress)))
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                        .stroke(torrent.progressColor.opacity(0.25), lineWidth: 1)
                )
        )
    }

    private func actionGrid(_ torrent: TorrentInfo) -> some View {
        HStack(spacing: 12) {
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
                color: AppColors.accent,
                isLoading: processingAction == .force,
                action: { performAction(.force, torrent: torrent) }
            )
            ActionTile(
                icon: "checkmark.shield.fill",
                label: OrbixStrings.btnRecheck,
                color: AppColors.accent,
                isLoading: processingAction == .recheck,
                action: { performAction(.recheck, torrent: torrent) }
            )
            ActionTile(
                icon: announceCooldown ? "clock.fill" : "antenna.radiowaves.left.and.right",
                label: announceCooldown ? OrbixStrings.btnWait : OrbixStrings.btnAnnounce,
                color: announceCooldown ? Color.secondary : AppColors.accent,
                isLoading: processingAction == .announce || announceCooldown,
                action: { performAction(.announce, torrent: torrent) }
            )
        }
    }

    private func transferSection(_ torrent: TorrentInfo) -> some View {
        VStack(spacing: 0) {
            SectionHeader(title: OrbixStrings.sectionTransfer)
            VStack(spacing: 0) {
                DetailRow(icon: "arrow.down.circle.fill", iconColor: AppColors.accent, label: OrbixStrings.labelDownloadSpeed, value: formatSpeed(torrent.dlspeed), valueColor: AppColors.accent)
                Divider().padding(.leading, 44)
                DetailRow(icon: "arrow.up.circle.fill", iconColor: AppColors.success, label: OrbixStrings.labelUploadSpeed, value: formatSpeed(torrent.upspeed), valueColor: AppColors.success)
                Divider().padding(.leading, 44)
                DetailRow(icon: "tray.and.arrow.down.fill", iconColor: .secondary, label: OrbixStrings.labelDownloaded, value: formatBytes(torrent.downloaded))
                Divider().padding(.leading, 44)
                DetailRow(icon: "tray.and.arrow.up.fill", iconColor: .secondary, label: OrbixStrings.labelUploaded, value: formatBytes(torrent.uploaded))
                Divider().padding(.leading, 44)
                DetailRow(icon: "chart.pie.fill", iconColor: .secondary, label: OrbixStrings.labelRatio, value: String(format: "%.2f", torrent.ratio), valueColor: torrent.ratio >= 1.0 ? AppColors.success : .secondary)
                if torrent.eta > 0 {
                    Divider().padding(.leading, 44)
                    DetailRow(icon: "timer", iconColor: .secondary, label: OrbixStrings.labelETA, value: torrent.etaFormatted)
                }
                Divider().padding(.leading, 44)
                DetailRow(icon: "person.2.fill", iconColor: .secondary, label: OrbixStrings.labelSeeds, value: "\(String(torrent.numSeeds)) / \(String(torrent.numLeechs))")
            }
            .background(
                RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                    .fill(Color(.systemBackground).opacity(0.9))
            )
        }
    }

    private func infoSection(_ props: TorrentProperties) -> some View {
        VStack(spacing: 0) {
            SectionHeader(title: OrbixStrings.sectionInfo)
            VStack(spacing: 0) {
                DetailRow(icon: "internaldrive.fill", iconColor: .secondary, label: OrbixStrings.labelTotalSize, value: formatBytes(props.totalSize))
                Divider().padding(.leading, 44)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 12) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                            .frame(width: 24)
                        Text(OrbixStrings.labelSavePath)
                            .font(.system(size: 15))
                            .foregroundColor(.primary)
                        Spacer()
                        CopyButton(textToCopy: props.savePath)
                    }
                    Text(props.savePath)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .padding(.leading, 36)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                if !props.category.isEmpty {
                    Divider().padding(.leading, 44)
                    DetailRow(icon: "square.grid.2x2.fill", iconColor: .secondary, label: OrbixStrings.labelCategory, value: props.category)
                }
                if !props.tags.isEmpty {
                    Divider().padding(.leading, 44)
                    DetailRow(icon: "tag.fill", iconColor: .secondary, label: OrbixStrings.labelTags, value: props.tags)
                }

                Divider().padding(.leading, 44)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 12) {
                        Image(systemName: "number.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                            .frame(width: 24)
                        Text(OrbixStrings.labelHash)
                            .font(.system(size: 15))
                            .foregroundColor(.primary)
                        Spacer()
                        CopyButton(textToCopy: props.hash)
                    }
                    Text(props.hash)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Color(.tertiaryLabel))
                        .padding(.leading, 36)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(
                RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                    .fill(Color(.systemBackground).opacity(0.9))
            )
        }
    }

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
                        .foregroundColor(AppColors.accent)
                }
                .padding(.trailing, 16)
            }
            VStack(spacing: 0) {
                ForEach(files.indices, id: \.self) { index in
                    let file = files[index]
                    VStack(alignment: .leading, spacing: 6) {
                        Text(file.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(2)

                        HStack {
                            Text(formatBytes(file.size))
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(file.progressPercent)%")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(file.progress >= 1.0 ? AppColors.success : AppColors.accent)
                        }

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 1, style: .continuous)
                                    .fill(Color(.separator).opacity(0.4))
                                RoundedRectangle(cornerRadius: 1, style: .continuous)
                                    .fill(file.progress >= 1.0 ? AppColors.success : AppColors.accent)
                                    .frame(width: max(0, geometry.size.width * CGFloat(file.progress)))
                            }
                        }
                        .frame(height: 3)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    if index < files.count - 1 {
                        Divider().padding(.leading, 16)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                    .fill(Color(.systemBackground).opacity(0.9))
            )
        }
    }

    // MARK: - Time Section
    private func timeSection(_ torrent: TorrentInfo, props: TorrentProperties?) -> some View {
        let added = props?.addedOn ?? torrent.addedOn
        let completed = props?.completionOn ?? torrent.completionOn
        return VStack(spacing: 0) {
            SectionHeader(title: OrbixStrings.sectionTime)
            VStack(spacing: 0) {
                DetailRow(icon: "calendar.badge.plus", iconColor: .secondary, label: OrbixStrings.labelAddTime, value: formatUnixTime(added))
                if completed > 0 {
                    Divider().padding(.leading, 44)
                    DetailRow(icon: "checkmark.seal.fill", iconColor: AppColors.success, label: OrbixStrings.labelCompleteTime, value: formatUnixTime(completed))
                }
            }
            .background(
                RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                    .fill(Color(.systemBackground).opacity(0.9))
            )
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
                        .foregroundColor(AppColors.accent)
                }
                .padding(.trailing, 16)
            }
            VStack(spacing: 0) {
                ForEach(trackers.indices, id: \.self) { index in
                    let tracker = trackers[index]
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
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
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if index < trackers.count - 1 {
                        Divider().padding(.leading, 16)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                    .fill(Color(.systemBackground).opacity(0.9))
            )
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
                                .foregroundColor(.primary)
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
                                .foregroundColor(.secondary)
                        }
                        if !peer.client.isEmpty {
                            Text(peer.client)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Color(.tertiaryLabel).opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if index < peers.count - 1 {
                        Divider()
                            .padding(.leading, 16)
                            .opacity(0.4)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
        }
    }

    private func countryColor(_ code: String) -> Color {
        switch code.uppercased() {
        case "CN", "HK", "TW", "MO": return AppColors.danger
        case "JP": return AppColors.accent
        case "US", "GB", "CA", "AU": return AppColors.success
        case "KR": return AppColors.warning
        default: return .secondary
        }
    }

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

    @ViewBuilder
    private func errorStateView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(AppColors.danger)

            Text(OrbixStrings.errLoadFailed)
                .font(.headline)
                .foregroundColor(.primary)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(OrbixStrings.btnRetry) {
                loadError = nil
                isLoading = true
                Task { await manualRefresh() }
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(.primary)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppColors.accent)
            )
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(40)
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

#if DEBUG
#Preview {
    TorrentDetailView(hash: "demo")
}
#endif




