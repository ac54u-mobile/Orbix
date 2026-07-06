import SwiftUI

struct TorrentDetailView: View {
    let hash: String

    @Environment(\.dismiss) private var dismiss
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
                ProgressView()
                    .controlSize(.large)
            } else if let err = loadError {
                errorStateView(err)
            } else if let torrent = torrent {
                List {
                    headerSection(torrent)

                    if torrent.statusBadge.isError && !torrent.errorString.isEmpty {
                        errorHintSection(torrent.errorString)
                    }

                    actionSection(torrent)

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
                .listStyle(.insetGrouped)
                .refreshable { await manualRefresh() }
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
                }
                .accessibilityLabel(OrbixStrings.navAdvancedControl)
            }
            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
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

    // MARK: - Header Section

    private func headerSection(_ torrent: TorrentInfo) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: torrent.statusBadge.iconName)
                        .font(.subheadline.weight(.semibold))
                    Text(torrent.statusBadge.displayName)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    if torrent.dlspeed > 0 {
                        Label(formatSpeed(torrent.dlspeed), systemImage: "arrow.down")
                            .font(.footnote.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.blue)
                    } else if torrent.upspeed > 0 {
                        Label(formatSpeed(torrent.upspeed), systemImage: "arrow.up")
                            .font(.footnote.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.green)
                    }
                }
                .foregroundStyle(torrent.statusBadge.statusColor)

                Text(torrent.name)
                    .font(.headline)
                    .lineLimit(3)

                HStack(alignment: .lastTextBaseline) {
                    Text("\(torrent.progressPercent)%")
                        .font(.system(.largeTitle, design: .rounded).bold())
                        .foregroundStyle(torrent.progressColor)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatBytes(torrent.downloaded))
                            .font(.footnote.weight(.medium).monospacedDigit())
                        Text("/ " + formatBytes(torrent.size))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }

                ProgressView(value: torrent.progress)
                    .tint(torrent.progressColor)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Action Section

    private func actionSection(_ torrent: TorrentInfo) -> some View {
        Section {
            HStack(spacing: 8) {
                actionButton(
                    icon: torrent.statusBadge.isPaused ? "play.fill" : "pause.fill",
                    label: torrent.statusBadge.isPaused ? OrbixStrings.btnStart : OrbixStrings.btnPause,
                    color: torrent.statusBadge.isPaused ? .green : .orange,
                    isLoading: processingAction == .pause
                ) { performAction(.pause, torrent: torrent) }

                actionButton(
                    icon: "bolt.fill",
                    label: OrbixStrings.btnForce,
                    color: .blue,
                    isLoading: processingAction == .force
                ) { performAction(.force, torrent: torrent) }

                actionButton(
                    icon: "checkmark.shield.fill",
                    label: OrbixStrings.btnRecheck,
                    color: .blue,
                    isLoading: processingAction == .recheck
                ) { performAction(.recheck, torrent: torrent) }

                actionButton(
                    icon: announceCooldown ? "clock.fill" : "antenna.radiowaves.left.and.right",
                    label: announceCooldown ? OrbixStrings.btnWait : OrbixStrings.btnAnnounce,
                    color: announceCooldown ? .secondary : .blue,
                    isLoading: processingAction == .announce || announceCooldown
                ) { performAction(.announce, torrent: torrent) }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
    }

    private func actionButton(icon: String, label: String, color: Color,
                              isLoading: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .frame(height: 22)
                } else {
                    Image(systemName: icon)
                        .font(.body.weight(.semibold))
                        .frame(height: 22)
                }
                Text(label)
                    .font(.caption2.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.bordered)
        .tint(color)
        .disabled(isLoading)
    }

    // MARK: - Transfer Section

    private func transferSection(_ torrent: TorrentInfo) -> some View {
        Section(OrbixStrings.sectionTransfer) {
            LabeledContent {
                Text(formatSpeed(torrent.dlspeed))
                    .monospacedDigit()
                    .foregroundStyle(.blue)
            } label: {
                Label(OrbixStrings.labelDownloadSpeed, systemImage: "arrow.down.circle.fill")
            }

            LabeledContent {
                Text(formatSpeed(torrent.upspeed))
                    .monospacedDigit()
                    .foregroundStyle(.green)
            } label: {
                Label(OrbixStrings.labelUploadSpeed, systemImage: "arrow.up.circle.fill")
            }

            LabeledContent(OrbixStrings.labelDownloaded, value: formatBytes(torrent.downloaded))
            LabeledContent(OrbixStrings.labelUploaded, value: formatBytes(torrent.uploaded))

            LabeledContent {
                Text(String(format: "%.2f", torrent.ratio))
                    .monospacedDigit()
                    .foregroundStyle(torrent.ratio >= 1.0 ? Color.green : Color.secondary)
            } label: {
                Text(OrbixStrings.labelRatio)
            }

            if torrent.eta > 0 {
                LabeledContent(OrbixStrings.labelETA, value: torrent.etaFormatted)
            }

            LabeledContent(OrbixStrings.labelSeeds,
                           value: "\(String(torrent.numSeeds)) / \(String(torrent.numLeechs))")
        }
    }

    // MARK: - Info Section

    private func infoSection(_ props: TorrentProperties) -> some View {
        Section(OrbixStrings.sectionInfo) {
            LabeledContent(OrbixStrings.labelTotalSize, value: formatBytes(props.totalSize))

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(OrbixStrings.labelSavePath)
                    Spacer()
                    CopyButton(textToCopy: props.savePath)
                }
                Text(props.savePath)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if !props.category.isEmpty {
                LabeledContent(OrbixStrings.labelCategory, value: props.category)
            }
            if !props.tags.isEmpty {
                LabeledContent(OrbixStrings.labelTags, value: props.tags)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(OrbixStrings.labelHash)
                    Spacer()
                    CopyButton(textToCopy: props.hash)
                }
                Text(props.hash)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Time Section

    @ViewBuilder
    private func timeSection(_ torrent: TorrentInfo, props: TorrentProperties?) -> some View {
        let added = props?.addedOn ?? torrent.addedOn
        let completed = props?.completionOn ?? torrent.completionOn
        Section(OrbixStrings.sectionTime) {
            LabeledContent(OrbixStrings.labelAddTime, value: formatUnixTime(added))
            if completed > 0 {
                LabeledContent(OrbixStrings.labelCompleteTime, value: formatUnixTime(completed))
            }
        }
    }

    // MARK: - Files Section

    private var filesSection: some View {
        Section {
            ForEach(files.indices, id: \.self) { index in
                let file = files[index]
                VStack(alignment: .leading, spacing: 6) {
                    Text(file.name)
                        .font(.subheadline)
                        .lineLimit(2)

                    HStack {
                        Text(formatBytes(file.size))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(file.progressPercent)%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(file.progress >= 1.0 ? Color.green : Color.blue)
                    }

                    ProgressView(value: file.progress)
                        .tint(file.progress >= 1.0 ? .green : .blue)
                }
                .padding(.vertical, 2)
            }
        } header: {
            HStack {
                Text("\(OrbixStrings.miscAddModeFile) (\(files.count))")
                Spacer()
                Button(OrbixStrings.btnManage) {
                    showFileSheet = true
                }
                .font(.footnote)
                .textCase(nil)
            }
        }
    }

    // MARK: - Trackers Section

    private var trackersSection: some View {
        Section {
            ForEach(trackers.indices, id: \.self) { index in
                let tracker = trackers[index]
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(tracker.statusColor)
                            .frame(width: 8, height: 8)
                        Text(tracker.statusText)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(tracker.statusColor)
                        Spacer()
                    }
                    Text("\(OrbixStrings.miscSeedsPrefix)：\(tracker.numSeeds) • 下载：\(tracker.numLeeches)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(tracker.url)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .padding(.vertical, 2)
            }
        } header: {
            HStack {
                Text(String(format: OrbixStrings.labelTrackersCount, trackers.count))
                Spacer()
                Button(OrbixStrings.btnManage) {
                    showTrackerSheet = true
                }
                .font(.footnote)
                .textCase(nil)
            }
        }
    }

    // MARK: - Peers Section

    private var peersSection: some View {
        Section(String(format: OrbixStrings.labelPeersCount, peers.count)) {
            ForEach(peers.indices, id: \.self) { index in
                let peer = peers[index]
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(peer.ip):\(String(peer.port))")
                            .font(.system(.footnote, design: .monospaced).weight(.medium))
                        if !peer.country.isEmpty {
                            Text(peer.country)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if peer.upSpeed > 0 {
                            Text("↑ \(formatSpeed(peer.upSpeed))")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.green)
                        }
                        Text("\(peer.progressPercent)%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    if !peer.client.isEmpty {
                        Text(peer.client)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Error Hint

    private func errorHintSection(_ message: String) -> some View {
        Section {
            Label {
                Text(message)
                    .font(.subheadline.weight(.medium))
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
            }
            .foregroundStyle(.red)
        }
    }

    // MARK: - Error State

    private func errorStateView(_ message: String) -> some View {
        ContentUnavailableView {
            Label(OrbixStrings.errLoadFailed, systemImage: "exclamationmark.triangle.fill")
        } description: {
            Text(message)
        } actions: {
            Button(OrbixStrings.btnRetry) {
                loadError = nil
                isLoading = true
                Task { await manualRefresh() }
            }
            .buttonStyle(.borderedProminent)
        }
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
    NavigationStack {
        TorrentDetailView(hash: "demo")
    }
}
#endif
