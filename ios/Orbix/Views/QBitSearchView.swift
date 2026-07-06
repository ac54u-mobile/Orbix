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

    @State private var downloadingNum: Int?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                pluginBar
                    .padding(.vertical, 8)

                if isLoading && results.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        ProgressView()
                        Text(OrbixStrings.msgSearchingAll)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                } else if let error = searchError {
                    ContentUnavailableView {
                        Label(OrbixStrings.errBuiltInSearchFailed, systemImage: "exclamationmark.triangle.fill")
                    } description: {
                        Text(error)
                    }
                } else if !query.isEmpty && results.isEmpty && !isLoading {
                    ContentUnavailableView.search(text: query)
                } else {
                    resultsList
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(OrbixStrings.navExplore)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    SearchSourceMenu()
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
                .font(.subheadline.weight(selected ? .semibold : .medium))
                .foregroundStyle(selected ? Color.white : Color.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(selected ? Color.accentColor : Color(.secondarySystemFill))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Results List

    private var resultsList: some View {
        List {
            Section {
                ForEach(results) { item in
                    resultRow(item)
                }
            } header: {
                if !results.isEmpty {
                    HStack {
                        Text(String(format: OrbixStrings.miscCountResults, results.count))
                        Spacer()
                        if status == "Running" {
                            ProgressView()
                                .controlSize(.mini)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func resultRow(_ item: SearchResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.fileName)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)

            HStack(spacing: 16) {
                Label(formatBytes(Int64(item.fileSize)), systemImage: "internaldrive")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if item.nbSeeders > 0 {
                    Label("\(item.nbSeeders)", systemImage: "arrow.up.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }

                if item.nbLeechers > 0 {
                    Label("\(item.nbLeechers)", systemImage: "arrow.down.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                }

                Spacer()

                Button {
                    AppHaptics.medium()
                    download(result: item)
                } label: {
                    if downloadingNum == item.num {
                        ProgressView()
                            .controlSize(.mini)
                    } else {
                        Image(systemName: "icloud.and.arrow.down.fill")
                            .font(.body.weight(.semibold))
                    }
                }
                .buttonStyle(.borderless)
                .disabled(downloadingNum != nil)
            }

            if !item.siteUrl.isEmpty {
                Text(item.siteUrl)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
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
                    _ = try await QBitApi.shared.addMagnet([result.descr])
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
