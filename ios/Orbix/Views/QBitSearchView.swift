import SwiftUI

struct QBitSearchView: View {
    @State private var query = ""
    @State private var plugins: [SearchPlugin] = []
    @State private var results: [SearchResult] = []
    @State private var selectedPlugins: Set<String> = ["all"]
    @State private var searchId: Int?
    @State private var status: String?
    @State private var isLoading = false
    @State private var searchTask: Task<Void, Never>?

    @State private var searchError: String?
    @ObservedObject private var searchMode = SearchModeState.shared

    @State private var downloadingNum: Int?

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundGradient.ignoresSafeArea()

                VStack(spacing: 0) {
                    pluginBar
                        .padding(.vertical, 8)

                    if isLoading && results.isEmpty {
                        VStack(spacing: 16) {
                            Spacer()
                            ProgressView()
                                .tint(AppColors.accentPrimary)
                            Text(OrbixStrings.msgSearchingAll)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppColors.textSecondary)
                            Spacer()
                        }
                    } else if let error = searchError {
                        VStack(spacing: 12) {
                            Spacer()
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 40, weight: .light))
                                .foregroundColor(AppColors.warning)
                        Text(error)
                            .descriptionSmall()
                            .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                            Spacer()
                        }
                    } else if !query.isEmpty && results.isEmpty && !isLoading {
                        VStack(spacing: 12) {
                            Spacer()
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 40, weight: .light))
                                .foregroundColor(AppColors.textTertiary)
                        Text(OrbixStrings.errNoResults)
                            .descriptionSmall()
                            Spacer()
                        }
                    } else {
                        resultsList
                    }
                }
            }
            .navigationTitle(OrbixStrings.navExplore)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        searchMode.use141.toggle()
                    } label: {
                        Image(systemName: "globe")
                            .foregroundColor(AppColors.accentPrimary)
                            .font(.system(size: 14))
                    }
                }
            }
            .searchable(text: $query, placement: .automatic, prompt: OrbixStrings.phSearchKeyword)
            .onChange(of: query) { _, _ in debounceSearch() }
            .onAppear { loadPlugins() }
            .onDisappear {
                searchTask?.cancel()
                if let sid = searchId {
                    Task { try? await QBitApi.shared.stopSearch(id: sid) }
                }
            }
        }
    }

    // MARK: - Plugin Bar

    private var pluginBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                pluginChip("all", label: OrbixStrings.filterAll)
                ForEach(plugins) { plugin in
                    if plugin.enabled {
                        pluginChip(plugin.id, label: plugin.name)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func pluginChip(_ id: String, label: String) -> some View {
        let selected = selectedPlugins.contains(id)
        return Button {
            AppHaptics.light()
            if id == "all" {
                selectedPlugins = ["all"]
            } else {
                selectedPlugins.remove("all")
                if selected { selectedPlugins.remove(id) } else { selectedPlugins.insert(id) }
            }
        } label: {
            Text(label)
                .font(.system(size: 14, weight: selected ? .semibold : .medium))
                .foregroundColor(selected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(selected ? AppColors.accentPrimary : Color.clear)
                        .background(
                            Capsule().fill(.regularMaterial)
                        )
                        .shadow(color: selected ? AppColors.accentPrimary.opacity(0.3) : .clear, radius: 4, y: 2)
                )
        }
    }

    // MARK: - Results List

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if !results.isEmpty {
                    HStack {
                        Text(String(format: OrbixStrings.miscCountResults, results.count))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                            .textCase(.uppercase)
                        Spacer()
                        if status == "Running" {
                            ProgressView()
                                .controlSize(.mini)
                                .tint(AppColors.accentPrimary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                }

                ForEach(results) { item in
                    resultRow(item)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func resultRow(_ item: SearchResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 6) {
                Text(item.fileName)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)
            }

            HStack(spacing: 16) {
                Label(formatBytes(Int64(item.fileSize)), systemImage: "internaldrive")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)

                if item.nbSeeders > 0 {
                    Label("\(item.nbSeeders)", systemImage: "arrow.up.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppColors.success)
                }

                if item.nbLeechers > 0 {
                    Label("\(item.nbLeechers)", systemImage: "arrow.down.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppColors.danger)
                }

                Spacer()

                Button {
                    AppHaptics.medium()
                    download(result: item)
                } label: {
                    if downloadingNum == item.num {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(AppColors.accentPrimary)
                            .padding(8)
                    } else {
                        Image(systemName: "icloud.and.arrow.down.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.accentPrimary)
                            .padding(8)
                            .background(
                                Circle().fill(AppColors.accentPrimary.opacity(0.1))
                            )
                    }
                }
                .disabled(downloadingNum != nil)
            }

            if !item.siteUrl.isEmpty {
                Text(item.siteUrl)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(AppColors.textTertiary)
                    .lineLimit(1)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                        .stroke(AppColors.glassBorder, lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 4)
        )
    }

    // MARK: - Data Loading

    private func loadPlugins() {
        Task {
            if let list = try? await QBitApi.shared.getSearchPlugins() {
                await MainActor.run { plugins = list }
            }
        }
    }

    // MARK: - Search

    private func debounceSearch() {
        if let sid = searchId {
            let oldId = sid
            searchId = nil
            Task { try? await QBitApi.shared.stopSearch(id: oldId) }
        }
        searchTask?.cancel()
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []
            searchError = nil
            isLoading = false
            return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            await runSearch()
        }
    }

    private func runSearch() async {
        await MainActor.run { isLoading = true; results = []; searchError = nil }
        do {
            let pList = selectedPlugins.contains("all")
                ? ["all"]
                : Array(selectedPlugins)
            guard let id = try await QBitApi.shared.startSearch(pattern: query, plugins: pList) else {
                await MainActor.run { isLoading = false }
                return
            }
            await MainActor.run { searchId = id }

            var attempts = 0
            while attempts < 30 {
                try await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                attempts += 1

                if let items = try? await QBitApi.shared.getSearchResults(id: id) {
                    await MainActor.run {
                        self.results = items.sorted { $0.nbSeeders > $1.nbSeeders }
                    }
                }

                if let s = try? await QBitApi.shared.getSearchStatus(id: id) {
                    let st = s["status"] as? String ?? ""
                    await MainActor.run { status = st }
                    if st == "Stopped" { break }
                }
            }
            await MainActor.run { isLoading = false }
        } catch {
            await MainActor.run {
                isLoading = false
                searchError = OrbixStrings.errBuiltInSearchFailed + ": " + error.localizedDescription
            }
        }
    }

    // MARK: - Download

    private func download(result: SearchResult) {
        downloadingNum = result.num
        AppHaptics.medium()
        Task {
            do {
                if !result.descr.isEmpty {
                    try await QBitApi.shared.addMagnet([result.descr])
                }
                await MainActor.run {
                    downloadingNum = nil
                    AppHaptics.success()
                    ToastManager.shared.show(String(format: String(localized: "已添加: %@"), result.fileName))
                }
            } catch {
                await MainActor.run {
                    downloadingNum = nil
                    AppHaptics.error()
                    ToastManager.shared.show(String(format: String(localized: "添加失败: %@"), error.localizedDescription))
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    QBitSearchView()
}
#endif
