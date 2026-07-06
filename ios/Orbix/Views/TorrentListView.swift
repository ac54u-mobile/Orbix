import SwiftUI

struct TorrentListView: View {
    @State private var torrents: [TorrentInfo] = []
    @State private var filter: TorrentFilter = .all
    @State private var globalDlSpeed: Int64 = 0
    @State private var globalUpSpeed: Int64 = 0
    @State private var showAddTorrent = false
    @State private var isLoading = true
    @State private var showSpeedPanel = false
    @State private var gDlLimitStr = ""
    @State private var gUlLimitStr = ""
    @State private var altSpeedEnabled = false
    @State private var selectedHash: String?
    @State private var editMode: EditMode = .inactive
    @State private var selectedHashes: Set<String> = []
    @State private var showBatchDeleteAlert = false
    @State private var processingAction: String?
    @State private var showErrorToast = false
    @State private var errorToastMessage = ""
    @State private var subtitleTorrent: TorrentInfo?
    @State private var searchText = ""
    @Environment(\.scenePhase) private var scenePhase

    enum TorrentFilter: CaseIterable {
        case all
        case downloading
        case seeding
        case active
        case paused
        case completed

        var displayName: String {
            switch self {
            case .all: return OrbixStrings.filterAll
            case .downloading: return OrbixStrings.statsDownloading
            case .seeding: return OrbixStrings.statsSeeding
            case .active: return OrbixStrings.filterActive
            case .paused: return OrbixStrings.statsPaused
            case .completed: return OrbixStrings.filterCompleted
            }
        }

        var icon: String {
            switch self {
            case .all:         return "square.stack"
            case .downloading: return "arrow.down.circle.fill"
            case .seeding:     return "arrow.up.circle.fill"
            case .active:      return "bolt.circle.fill"
            case .paused:      return "pause.circle.fill"
            case .completed:   return "checkmark.circle.fill"
            }
        }
    }

    private let timer = Timer.publish(every: RefreshInterval.torrentList, on: .main, in: .common).autoconnect()
    @State private var refreshSuppressed = false
    @Namespace private var animationNamespace

    var body: some View {
        NavigationStack {
            ZStack {
                if isLoading {
                    loadingContent
                } else if filteredTorrents.isEmpty {
                    emptyContent
                } else {
                    torrentList
                }
            }
            // 撑满屏幕，防止加载/空状态时容器收缩导致顶部过滤栏悬在屏幕中间
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom) {
                bottomInsetContent
            }
            .animation(.default, value: editMode)
            .navigationTitle(OrbixStrings.tabTorrents)
            .navigationBarTitleDisplayMode(.inline)
            // .always 固定搜索栏，避免下拉刷新时搜索栏被拉出、启动时布局跳动
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: Text(String(localized: "搜索任务名称", comment: "Search torrent name"))
            )
            .toolbar { toolbarContent }
            .onAppear { refresh() }
            .onReceive(timer) { _ in
                guard !refreshSuppressed else { return }
                refresh()
            }
            .onChange(of: scenePhase) { _, newPhase in
                refreshSuppressed = newPhase != .active
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                filterBar
            }
        }
        .sheet(isPresented: $showAddTorrent) {
            AddTorrentView()
        }
        .sheet(isPresented: $showSpeedPanel) {
            speedPanel
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $subtitleTorrent) { torrent in
            ServerSubtitleView(torrent: torrent)
        }
        .alert(OrbixStrings.miscDeleteTorrentTitle, isPresented: $showBatchDeleteAlert) {
                Button(OrbixStrings.btnDeleteTaskFiles, role: .destructive) { executeBatchDelete(deleteFiles: true) }
                Button(OrbixStrings.btnDeleteTaskOnly, role: .destructive) { executeBatchDelete(deleteFiles: false) }
                Button(OrbixStrings.btnCancel, role: .cancel) {}
            } message: {
                Text(String(format: OrbixStrings.infoBatchDeleteConfirm, selectedHashes.count))
        }
        .toast(isPresented: $showErrorToast, type: .error, message: errorToastMessage)
        .task {
            // 同步字幕任务完成状态，给卡片打"已翻译字幕"标
            guard SubtitleServiceConfig.load().isConfigured else { return }
            if let jobs = try? await SubtitleServerApi.shared.listJobs() {
                await MainActor.run { SubtitleBadgeStore.shared.sync(with: jobs) }
            }
        }
    }

    // MARK: - Torrent List
    private var torrentList: some View {
        List(selection: $selectedHashes) {
            if filter == .all {
                ForEach(statusGroups) { group in
                    Section {
                        ForEach(group.torrents) { torrent in
                            torrentRowView(torrent)
                        }
                    } header: {
                        HStack {
                            Text(group.title)
                            Spacer()
                            Text("\(group.torrents.count)")
                                .monospacedDigit()
                        }
                    }
                }
            } else {
                Section {
                    ForEach(filteredTorrents) { torrent in
                        torrentRowView(torrent)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .environment(\.editMode, $editMode)
        .refreshable { await manualRefresh() }
        .navigationDestination(item: $selectedHash) { hash in
            // 相册式滑动 — 在详情页左右滑动即可切换相邻种子
            TorrentDetailPagerView(
                hashes: visibleHashes,
                initialHash: hash
            )
        }
    }

    /// 与列表可见顺序一致（全部过滤时按状态分组展开）
    private var visibleHashes: [String] {
        filter == .all
            ? statusGroups.flatMap { $0.torrents.map(\.hash) }
            : filteredTorrents.map(\.hash)
    }

    @ViewBuilder
    private func torrentRowView(_ torrent: TorrentInfo) -> some View {
        let row = TorrentRow(torrent: torrent)
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    executeSingleAction(.deleteFiles, torrent)
                } label: {
                    Label(OrbixStrings.btnDelete, systemImage: "trash")
                }
            }
            .swipeActions(edge: .leading) {
                Button {
                    executeSingleAction(torrent.statusBadge.isPaused ? .start : .stop, torrent)
                } label: {
                    Label(
                        torrent.statusBadge.isPaused ? OrbixStrings.btnStart : OrbixStrings.btnPause,
                        systemImage: torrent.statusBadge.isPaused ? "play.fill" : "pause.fill"
                    )
                }
                .tint(torrent.statusBadge.isPaused ? .green : .orange)
            }
            .contextMenu { contextMenuItems(for: torrent) }
            .accessibilityAction(named: Text(torrent.statusBadge.isPaused ? OrbixStrings.btnStart : OrbixStrings.btnPause)) {
                executeSingleAction(torrent.statusBadge.isPaused ? .start : .stop, torrent)
            }
            .tag(torrent.hash)

        // 编辑模式下由 List 原生处理选择，非编辑模式点按进入详情
        if editMode == .inactive {
            row
                .contentShape(Rectangle())
                .onTapGesture {
                    AppHaptics.light()
                    selectedHash = torrent.hash
                }
        } else {
            row
        }
    }

    // MARK: - Status Groups
    private struct StatusGroup: Identifiable {
        let id: String
        let title: String
        let torrents: [TorrentInfo]
    }

    private var statusGroups: [StatusGroup] {
        let list = filteredTorrents
        var buckets: [(id: String, title: String, items: [TorrentInfo])] = [
            ("error", OrbixStrings.statsError, []),
            ("downloading", OrbixStrings.statsDownloading, []),
            ("seeding", OrbixStrings.statsSeeding, []),
            ("paused", OrbixStrings.statsPaused, []),
            ("completed", OrbixStrings.filterCompleted, []),
            ("other", String(localized: "其他", comment: "Other"), [])
        ]
        for t in list {
            let badge = t.statusBadge
            let index: Int
            if badge.isError {
                index = 0
            } else if badge.isDownloadRelated && !badge.isPaused {
                index = 1
            } else if badge.isUploadRelated && !badge.isPaused {
                index = 2
            } else if badge.isPaused && !t.isCompleted {
                index = 3
            } else if t.isCompleted {
                index = 4
            } else {
                index = 5
            }
            buckets[index].items.append(t)
        }
        return buckets
            .filter { !$0.items.isEmpty }
            .map { StatusGroup(id: $0.id, title: $0.title, torrents: $0.items) }
    }

    private var loadingContent: some View {
        ProgressView()
            .controlSize(.large)
            .transition(.opacity)
    }

    @ViewBuilder
    private var emptyContent: some View {
        if !searchText.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else {
            EmptyStateView(
                icon: filter == .all ? "tray" : "line.3.horizontal.decrease.circle",
                title: filter == .all ? OrbixStrings.msgNoTorrents : OrbixStrings.msgNoMatchingTorrents,
                subtitle: filter == .all ? String(localized: "点击右上角 + 添加新任务", comment: "") : String(localized: "尝试切换到其他过滤条件", comment: ""),
                actionTitle: filter == .all ? OrbixStrings.navAddTorrent : nil,
                action: filter == .all ? { showAddTorrent = true } : nil
            )
        }
    }

    private var isEditing: Bool { editMode == .active }

    private var bottomInsetContent: some View {
        VStack(spacing: 8) {
            if isEditing && !selectedHashes.isEmpty {
                batchActionBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if !isEditing && (globalDlSpeed > 0 || globalUpSpeed > 0) {
                GlobalSpeedPill(dl: globalDlSpeed, up: globalUpSpeed)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.9)))
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                AppHaptics.medium()
                withAnimation {
                    if isEditing {
                        selectedHashes.removeAll()
                        editMode = .inactive
                    } else {
                        editMode = .active
                    }
                }
            } label: {
                Text(isEditing ? OrbixStrings.btnDone : OrbixStrings.btnEdit)
                    .fontWeight(.medium)
            }
        }
        ToolbarItem(placement: .navigationBarLeading) {
            if !isEditing {
                Button { showSpeedPanel = true } label: {
                    Image(systemName: altSpeedEnabled ? "tortoise.fill" : "speedometer")
                        .foregroundStyle(altSpeedEnabled ? Color.orange : Color.accentColor)
                }
                .accessibilityLabel(OrbixStrings.sectionGlobalSpeedLimit)
            } else {
                Button {
                    AppHaptics.selection()
                    if selectedHashes.count == filteredTorrents.count {
                        selectedHashes.removeAll()
                    } else {
                        selectedHashes = Set(filteredTorrents.map(\.hash))
                    }
                } label: {
                    Text(selectedHashes.count == filteredTorrents.count ? OrbixStrings.btnDeselectAll : OrbixStrings.btnSelectAll)
                        .fontWeight(.medium)
                }
            }
        }
        ToolbarItem(placement: .primaryAction) {
            if !isEditing {
                Button {
                    showAddTorrent = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(OrbixStrings.navAddTorrent)
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TorrentFilter.allCases, id: \.self) { f in
                    filterChip(f)
                        // 一屏恰好并排 4 个，其余向右滑动查看
                        .containerRelativeFrame(.horizontal, count: 4, spacing: 8)
                }
            }
            .scrollTargetLayout()
            .padding(.vertical, 8)
        }
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private func filterChip(_ f: TorrentFilter) -> some View {
        let isSelected = filter == f
        let itemCount = count(for: f)
        return Button {
            AppHaptics.selection()
            withAnimation(.snappy) { filter = f }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: f.icon)
                    .font(.caption)
                Text(f.displayName)
                if itemCount > 0 {
                    Text("\(itemCount)")
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Color.secondary)
                }
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .lineLimit(1)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    if isSelected {
                        Capsule()
                            .fill(Color.accentColor)
                            .matchedGeometryEffect(id: "filterPill", in: animationNamespace)
                    } else {
                        Capsule()
                            .fill(Color(.secondarySystemFill))
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(f.displayName)
        .accessibilityValue("\(itemCount)")
    }

    // MARK: - Context Menu
    @ViewBuilder
    private func contextMenuItems(for torrent: TorrentInfo) -> some View {
        if torrent.statusBadge.isPaused {
            Button {
                executeSingleAction(.start, torrent)
            } label: {
                Label(OrbixStrings.btnStart, systemImage: "play.fill")
            }
        } else if torrent.isActive {
            Button {
                executeSingleAction(.stop, torrent)
            } label: {
                Label(OrbixStrings.btnPause, systemImage: "pause.fill")
            }
        }

        if !torrent.statusBadge.isError {
            Button {
                executeSingleAction(.force, torrent)
            } label: {
                Label(OrbixStrings.btnForce, systemImage: "bolt.fill")
            }
        }

        Button {
            executeSingleAction(.recheck, torrent)
        } label: {
            Label(OrbixStrings.btnRecheck, systemImage: "checkmark.shield.fill")
        }

        Button {
            executeSingleAction(.announce, torrent)
        } label: {
            Label(OrbixStrings.btnAnnounce, systemImage: "antenna.radiowaves.left.and.right")
        }

        Divider()

        Button {
            subtitleTorrent = torrent
        } label: {
            Label(String(localized: "提取字幕", comment: ""), systemImage: "waveform")
        }

        Button(role: .destructive) {
            executeSingleAction(.deleteTask, torrent)
        } label: {
            Label(OrbixStrings.btnDeleteTaskOnly, systemImage: "trash")
        }

        Button(role: .destructive) {
            executeSingleAction(.deleteFiles, torrent)
        } label: {
            Label(OrbixStrings.btnDeleteTaskFiles, systemImage: "trash.fill")
        }
    }

    // MARK: - Single Action
    private enum SingleActionType {
        case start, stop, force, recheck, announce, deleteTask, deleteFiles
    }

    private func executeSingleAction(_ type: SingleActionType, _ torrent: TorrentInfo) {
        AppHaptics.medium()
        processingAction = torrent.hash

        Task {
            do {
                switch type {
                case .start:
                    try await QBitApi.shared.startTorrent(torrent.hash)
                case .stop:
                    try await QBitApi.shared.stopTorrent(torrent.hash)
                case .force:
                    try await QBitApi.shared.forceStartTorrent(torrent.hash)
                case .recheck:
                    try await QBitApi.shared.recheckTorrent(torrent.hash)
                case .announce:
                    try await QBitApi.shared.reannounceTorrent(torrent.hash)
                case .deleteTask:
                    try await QBitApi.shared.deleteTorrent(torrent.hash, deleteFiles: false)
                    await MainActor.run {
                        withAnimation(.default) {
                            self.torrents.removeAll { $0.hash == torrent.hash }
                        }
                    }
                case .deleteFiles:
                    try await QBitApi.shared.deleteTorrent(torrent.hash, deleteFiles: true)
                    await MainActor.run {
                        withAnimation(.default) {
                            self.torrents.removeAll { $0.hash == torrent.hash }
                        }
                    }
                }
                if type != .deleteTask && type != .deleteFiles {
                    await MainActor.run { processingAction = nil }
                    refresh()
                }
                AppHaptics.success()
            } catch {
                await MainActor.run { processingAction = nil }
                AppHaptics.error()
            }
        }
    }

    // MARK: - Batch Actions
    private var batchActionBar: some View {
        HStack(spacing: 12) {
            Text(String(format: OrbixStrings.miscSelectedCount, selectedHashes.count))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                executeBatchAction(.stop)
            } label: {
                Label(OrbixStrings.btnBatchPause, systemImage: "pause.fill")
                    .font(.footnote.weight(.medium))
            }
            .tint(.orange)

            Button {
                executeBatchAction(.start)
            } label: {
                Label(OrbixStrings.btnBatchResume, systemImage: "play.fill")
                    .font(.footnote.weight(.medium))
            }
            .tint(.green)

            Button(role: .destructive) {
                showBatchDeleteAlert = true
            } label: {
                Label(OrbixStrings.btnBatchDelete, systemImage: "trash")
                    .font(.footnote.weight(.medium))
            }
            .tint(.red)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func executeBatchAction(_ type: SingleActionType) {
        AppHaptics.medium()

        let hashes = selectedHashes.joined(separator: "|")

        Task {
            do {
                switch type {
                case .start:
                    try await QBitApi.shared.startTorrent(hashes)
                case .stop:
                    try await QBitApi.shared.stopTorrent(hashes)
                default:
                    break
                }
                await MainActor.run { selectedHashes.removeAll() }
                refresh()
                AppHaptics.success()
            } catch {
                AppHaptics.error()
            }
        }
    }

    private func executeBatchDelete(deleteFiles: Bool) {
        AppHaptics.heavy()

        let hashes = selectedHashes.joined(separator: "|")

        Task {
            do {
                try await QBitApi.shared.deleteTorrent(hashes, deleteFiles: deleteFiles)
                await MainActor.run {
                    withAnimation(.default) {
                        torrents.removeAll { selectedHashes.contains($0.hash) }
                        selectedHashes.removeAll()
                    }
                }
                AppHaptics.success()
            } catch {
                AppHaptics.error()
            }
        }
    }

    // MARK: - Filter & Sort

    private func applyFilter(_ f: TorrentFilter, to list: [TorrentInfo]) -> [TorrentInfo] {
        switch f {
        case .all: list
        case .downloading: list.filter { $0.statusBadge.isDownloadRelated }
        case .seeding: list.filter { $0.statusBadge.isUploadRelated }
        case .active: list.filter { $0.isActive }
        case .paused: list.filter { $0.statusBadge.isPaused }
        case .completed: list.filter { $0.isCompleted }
        }
    }

    private var searchedTorrents: [TorrentInfo] {
        guard !searchText.isEmpty else { return torrents }
        return torrents.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private func count(for f: TorrentFilter) -> Int {
        applyFilter(f, to: searchedTorrents).count
    }

    private var filteredTorrents: [TorrentInfo] {
        applyFilter(filter, to: searchedTorrents)
            .sorted { $0.addedOn > $1.addedOn }
    }

    private func refresh() {
        Task {
            do {
                let list = try await QBitApi.shared.getTorrents()
                let transfer = try? await QBitApi.shared.getTransferInfo()
                let prefs = try? await QBitApi.shared.getPreferences()

                await MainActor.run {
                    self.torrents = list
                    self.globalDlSpeed = transfer?.dlInfoSpeed ?? 0
                    self.globalUpSpeed = transfer?.upInfoSpeed ?? 0
                    if let p = prefs {
                        self.altSpeedEnabled = p["alt_speed_limit_enabled"] as? Bool ?? false
                        if gDlLimitStr.isEmpty, let dl = p["dl_limit"] as? Int64, dl > 0 {
                            gDlLimitStr = "\(dl / 1024)"
                        }
                        if gUlLimitStr.isEmpty, let ul = p["up_limit"] as? Int64, ul > 0 {
                            gUlLimitStr = "\(ul / 1024)"
                        }
                    }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorToastMessage = String(format: String(localized: "获取种子列表失败: %@", comment: "Failed to fetch torrent list: error"), error.localizedDescription)
                    self.showErrorToast = true
                }
            }
        }
    }
    
    @Sendable private func manualRefresh() async {
        let list = (try? await QBitApi.shared.getTorrents()) ?? torrents
        let transfer = try? await QBitApi.shared.getTransferInfo()
        await MainActor.run {
            self.torrents = list
            self.globalDlSpeed = transfer?.dlInfoSpeed ?? 0
            self.globalUpSpeed = transfer?.upInfoSpeed ?? 0
        }
    }

    // MARK: - Speed Control Panel
    private var speedPanel: some View {
        NavigationStack {
            List {
                Section {
                    Toggle(isOn: $altSpeedEnabled) {
                        Label(OrbixStrings.labelAltSpeedMode, systemImage: "tortoise")
                    }
                    .onChange(of: altSpeedEnabled) { _, _ in
                        Task {
                            try? await QBitApi.shared.toggleSpeedLimitsMode()
                            AppHaptics.success()
                        }
                    }
                } header: {
                    Text(OrbixStrings.sectionMode)
                } footer: {
                    Text(OrbixStrings.infoAltSpeedHint)
                }

                SpeedLimitSection(
                    sectionTitle: OrbixStrings.sectionGlobalSpeedLimit,
                    footerText: OrbixStrings.infoEmptyZeroGlobalHint,
                    dlLimitStr: $gDlLimitStr,
                    ulLimitStr: $gUlLimitStr,
                    onApply: {
                        Task {
                            let dl = Int64(gDlLimitStr) ?? -1
                            let ul = Int64(gUlLimitStr) ?? -1
                            if dl >= 0 { try? await QBitApi.shared.setGlobalDownloadLimit(dl > 0 ? dl * 1024 : 0) }
                            if ul >= 0 { try? await QBitApi.shared.setGlobalUploadLimit(ul > 0 ? ul * 1024 : 0) }
                            AppHaptics.success()
                        }
                    }
                )
            }
            .listStyle(.insetGrouped)
            .navigationTitle(OrbixStrings.navGlobalControl)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(OrbixStrings.btnDone) { showSpeedPanel = false }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    TorrentListView()
}
#endif

