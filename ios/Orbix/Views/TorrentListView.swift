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
    @State private var sortOrder: TorrentSort = .dateAdded
    @State private var selectedHash: String?
    @State private var isEditMode = false
    @State private var selectedHashes: Set<String> = []
    @State private var showBatchDeleteAlert = false
    @State private var processingAction: String?
    @State private var showErrorToast = false
    @State private var errorToastMessage = ""
    @State private var showSubtitleTranslate = false
    @State private var showVideoSubtitle = false
    @State private var translateTorrentName = ""
    @Environment(\.scenePhase) private var scenePhase

    enum TorrentSort: CaseIterable {
        case dateAdded
        case name
        case progress
        case size
        case ratio
        case dlSpeed
        case upSpeed

        var displayName: String {
            switch self {
            case .dateAdded: return OrbixStrings.sortDateAdded
            case .name: return OrbixStrings.sortName
            case .progress: return OrbixStrings.sortProgress
            case .size: return OrbixStrings.sortSize
            case .ratio: return OrbixStrings.sortRatio
            case .dlSpeed: return OrbixStrings.sortDLSpeed
            case .upSpeed: return OrbixStrings.sortULSpeed
            }
        }

        var icon: String {
            switch self {
            case .dateAdded: return "calendar"
            case .name: return "textformat.abc"
            case .progress: return "chart.bar"
            case .size: return "internaldrive"
            case .ratio: return "chart.line.uptrend.xyaxis"
            case .dlSpeed: return "arrow.down"
            case .upSpeed: return "arrow.up"
            }
        }
    }

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
            .orbixBackground()
            .safeAreaInset(edge: .bottom) {
                bottomInsetContent
            }
            .animation(AppMotion.standardCurve, value: globalDlSpeed > 0 || globalUpSpeed > 0)
            .animation(AppMotion.mediumAnim(), value: isEditMode)
            .animation(AppMotion.mediumAnim(), value: selectedHashes.count)
            .animation(AppMotion.mediumAnim(), value: isLoading)
            .navigationTitle(OrbixStrings.tabTorrents)
            .navigationBarTitleDisplayMode(.inline)
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
        .sheet(isPresented: $showSubtitleTranslate) {
            SubtitleTranslateView()
        }
        .sheet(isPresented: $showVideoSubtitle) {
            VideoSubtitleView()
        }
        .alert(OrbixStrings.miscDeleteTorrentTitle, isPresented: $showBatchDeleteAlert) {
                Button(OrbixStrings.btnDeleteTaskFiles, role: .destructive) { executeBatchDelete(deleteFiles: true) }
                Button(OrbixStrings.btnDeleteTaskOnly, role: .destructive) { executeBatchDelete(deleteFiles: false) }
                Button(OrbixStrings.btnCancel, role: .cancel) {}
            } message: {
                Text(String(format: OrbixStrings.infoBatchDeleteConfirm, selectedHashes.count))
        }
        .toast(isPresented: $showErrorToast, type: .error, message: errorToastMessage)
    }

    // MARK: - Torrent List
    private var torrentList: some View {
        List {
            ForEach(filteredTorrents) { torrent in
                torrentRowView(torrent)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .refreshable { await manualRefresh() }
        .navigationDestination(item: $selectedHash) { hash in
            // 相册式滑动 — 在详情页左右滑动即可切换相邻种子
            TorrentDetailPagerView(
                hashes: filteredTorrents.map(\.hash),
                initialHash: hash
            )
        }
    }

    private func torrentRowView(_ torrent: TorrentInfo) -> some View {
        HStack(spacing: 0) {
            if isEditMode {
                selectionIcon(for: torrent)
                    .padding(.trailing, AppSpacing.md)
            }
            TorrentRow(torrent: torrent)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
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
            .tint(torrent.statusBadge.isPaused ? AppColors.success : AppColors.warning)
        }
        .contextMenu { contextMenuItems(for: torrent) }
        .contentShape(Rectangle())
        .onTapGesture {
            if isEditMode {
                toggleSelection(torrent.hash)
            } else {
                AppHaptics.light()
                selectedHash = torrent.hash
            }
        }
    }

    private var loadingContent: some View {
        SkeletonList(count: 6)
            .padding(.top, AppSpacing.sm)
            .transition(.opacity)
    }

    private var emptyContent: some View {
        EmptyStateView(
            icon: filter == .all ? "tray" : "line.3.horizontal.decrease.circle",
            title: filter == .all ? OrbixStrings.msgNoTorrents : OrbixStrings.msgNoMatchingTorrents,
            subtitle: filter == .all ? String(localized: "点击右上角 + 添加新任务", comment: "") : String(localized: "尝试切换到其他过滤条件", comment: ""),
            actionTitle: filter == .all ? OrbixStrings.navAddTorrent : nil,
            action: filter == .all ? { showAddTorrent = true } : nil
        )
    }

    private var bottomInsetContent: some View {
        VStack(spacing: 8) {
            if isEditMode && !selectedHashes.isEmpty {
                batchActionBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if !isEditMode && (globalDlSpeed > 0 || globalUpSpeed > 0) {
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
                if isEditMode {
                    selectedHashes.removeAll()
                    isEditMode = false
                } else {
                    isEditMode = true
                }
            } label: {
                Text(isEditMode ? OrbixStrings.btnDone : OrbixStrings.btnEdit)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.accentPrimary)
            }
        }
        ToolbarItem(placement: .navigationBarLeading) {
            if !isEditMode {
                Button { showSpeedPanel = true } label: {
                    Image(systemName: altSpeedEnabled ? "tortoise.fill" : "speedometer")
                        .foregroundColor(altSpeedEnabled ? AppColors.warning : AppColors.accentPrimary)
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
                        .foregroundColor(AppColors.accentPrimary)
                }
            }
        }
        ToolbarItem(placement: .navigationBarLeading) {
            if !isEditMode {
                Menu {
                    ForEach(TorrentSort.allCases, id: \.self) { sort in
                        Button {
                            sortOrder = sort
                        } label: {
                            HStack {
                                Text(sort.displayName)
                                if sortOrder == sort {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .foregroundColor(AppColors.accentPrimary)
                }
                .accessibilityLabel(OrbixStrings.sortName)
            }
        }
        ToolbarItem(placement: .primaryAction) {
            if !isEditMode {
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
            LazyHStack(spacing: AppSpacing.sm) {
                ForEach(TorrentFilter.allCases, id: \.self) { f in
                    Button {
                        AppHaptics.selection()
                        withAnimation(AppMotion.fastAnim()) { filter = f }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: f.icon)
                                .sfSymbolFrame()
                            Text(f.displayName)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(filter == f ? .white : AppColors.textPrimary)
                        .padding(.vertical, 7)
                        .padding(.horizontal, 13)
                        .background(
                            ZStack {
                                if filter == f {
                                    Capsule()
                                        .fill(AppColors.accentPrimary)
                                        .matchedGeometryEffect(id: "filterPill", in: animationNamespace)
                                } else {
                                    Capsule()
                                        .fill(Color(.tertiarySystemFill).opacity(0.6))
                                }
                            }
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel(f.displayName)
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, 10)
        }
        .background(.ultraThinMaterial)
        .ignoresSafeArea(edges: .horizontal)
    }

    // MARK: - Selection
    private func selectionIcon(for torrent: TorrentInfo) -> some View {
        let isSelected = selectedHashes.contains(torrent.hash)
        return Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 22))
            .foregroundColor(isSelected ? AppColors.accentPrimary : AppColors.textTertiary)
            .frame(width: 28)
    }

    private func toggleSelection(_ hash: String) {
        AppHaptics.selection()
        if selectedHashes.contains(hash) {
            selectedHashes.remove(hash)
        } else {
            selectedHashes.insert(hash)
        }
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
            translateTorrentName = torrent.name
            showSubtitleTranslate = true
        } label: {
            Label(String(localized: "翻译字幕", comment: ""), systemImage: "translate")
        }

        Button {
            showVideoSubtitle = true
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
                        withAnimation(AppMotion.mediumAnim()) {
                            self.torrents.removeAll { $0.hash == torrent.hash }
                        }
                    }
                case .deleteFiles:
                    try await QBitApi.shared.deleteTorrent(torrent.hash, deleteFiles: true)
                    await MainActor.run {
                        withAnimation(AppMotion.mediumAnim()) {
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
        HStack(spacing: AppSpacing.md) {
            Text(String(format: OrbixStrings.miscSelectedCount, selectedHashes.count))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            Button {
                executeBatchAction(.stop)
            } label: {
                Label(OrbixStrings.btnBatchPause, systemImage: "pause.fill")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(ScaleButtonStyle())
            .tint(AppColors.warning)

            Button {
                executeBatchAction(.start)
            } label: {
                Label(OrbixStrings.btnBatchResume, systemImage: "play.fill")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(ScaleButtonStyle())
            .tint(AppColors.success)

            Button(role: .destructive) {
                showBatchDeleteAlert = true
            } label: {
                Label(OrbixStrings.btnBatchDelete, systemImage: "trash")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(ScaleButtonStyle())
            .tint(AppColors.danger)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                        .stroke(AppColors.glassBorder, lineWidth: 0.5)
                )
        )
        .padding(.horizontal, AppSpacing.lg)
        .padding(.bottom, AppSpacing.sm)
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
                    withAnimation(AppMotion.mediumAnim()) {
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

    private var filteredTorrents: [TorrentInfo] {
        let base = switch filter {
        case .all: torrents
        case .downloading: torrents.filter { $0.statusBadge.isDownloadRelated }
        case .seeding: torrents.filter { $0.statusBadge.isUploadRelated }
        case .active: torrents.filter { $0.isActive }
        case .paused: torrents.filter { $0.statusBadge.isPaused }
        case .completed: torrents.filter { $0.isCompleted }
        }
        switch sortOrder {
        case .dateAdded: return base.sorted { $0.addedOn > $1.addedOn }
        case .name: return base.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        case .progress: return base.sorted { $0.progress > $1.progress }
        case .size: return base.sorted { $0.size > $1.size }
        case .ratio: return base.sorted { $0.ratio > $1.ratio }
        case .dlSpeed: return base.sorted { $0.dlspeed > $1.dlspeed }
        case .upSpeed: return base.sorted { $0.upspeed > $1.upspeed }
        }
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
                    HStack {
                        Label(OrbixStrings.labelAltSpeedMode, systemImage: "tortoise")
                            .foregroundColor(AppColors.textPrimary)
                        Spacer()
                        Toggle("", isOn: $altSpeedEnabled)
                            .labelsHidden()
                            .tint(AppColors.warning)
                            .onChange(of: altSpeedEnabled) { _, _ in
                                Task {
                                    try? await QBitApi.shared.toggleSpeedLimitsMode()
                                    AppHaptics.success()
                                }
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
            .scrollContentBackground(.hidden)
            .orbixBackground()
            .navigationTitle(OrbixStrings.navGlobalControl)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(OrbixStrings.btnDone) { showSpeedPanel = false }
                        .fontWeight(.medium).foregroundColor(AppColors.accentPrimary)
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

