import SwiftUI

struct SearchView: View {
    @State private var query = ""
    @State private var results: [ScrapedTorrent] = []
    @State private var allResults: [ScrapedTorrent] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var state: SearchState = .idle
    @State private var bookmarks: Set<String> = []
    @State private var selectedTorrent: ScrapedTorrent?
    @State private var showMediaViewer = false
    @State private var mediaViewerIndex = 0
    @State private var currentPage = 1
    @State private var hasMorePages = true
    @State private var showingBookmarks = false
    @State private var lastLoadTime: Date = .distantPast
    @State private var translatingCode: String?
    @State private var translatedText: String?
    @State private var showTranslation = false
    @State private var exportedFileURL: URL?
    @State private var showExportSheet = false
    @State private var showVideoSubtitle = false

    enum SearchState { case idle, loading, results, empty, error(String) }

    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Group {
                switch state {
                case .idle: idleView
                case .loading: loadingView
                case .results: resultsView
                case .empty: emptyHint(OrbixStrings.errNoSearchResults, icon: "magnifyingglass")
                case .error(let m): emptyHint(m, icon: "exclamationmark.triangle", isError: true)
                }
            }
            .navigationTitle(OrbixStrings.navSearch)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        SearchModeState.shared.use141 = false
                    } label: {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        AppHaptics.light()
                        withAnimation(.none) { showingBookmarks.toggle() }
                    } label: {
                        Image(systemName: showingBookmarks ? "heart.fill" : (bookmarks.isEmpty ? "heart" : "heart.fill"))
                    }
                    .accessibilityLabel(OrbixStrings.navSearch)
                    .id("bookmark_\(bookmarks.hashValue)_\(showingBookmarks)")
                }
            }
            .onAppear {
                loadBookmarks()
                let stale = Date().timeIntervalSince(lastLoadTime) > 300
                if allResults.isEmpty || stale { loadLatest() }
            }
            .sheet(item: $selectedTorrent) { TorrentDetailSheet(torrent: $0, bookmarks: $bookmarks, onChanged: saveBookmarks) }
            .fullScreenCover(isPresented: $showMediaViewer) {
                let imgs = results.map { $0.thumbnail ?? "" }.filter { !$0.isEmpty }
                if !imgs.isEmpty {
                    MediaViewer(images: imgs, initialIndex: mediaViewerIndex)
                }
            }
            .alert(String(localized: "翻译结果", comment: ""), isPresented: $showTranslation) {
                Button(OrbixStrings.btnDone) {}
                Button(String(localized: "导出字幕 (.srt)", comment: "")) {
                    exportSRT()
                }
            } message: {
                Text(translatedText ?? "")
            }
            .sheet(isPresented: $showExportSheet) {
                if let url = exportedFileURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .sheet(isPresented: $showVideoSubtitle) {
                VideoSubtitleView()
            }
        }
    }

    // MARK: - Idle / Trending
    private var idleView: some View {
        List {
            Section {
                if results.isEmpty {
                    loadingPlaceholderRows
                } else {
                    torrentRows(results)
                }
            } header: {
                VStack(alignment: .leading, spacing: 4) {
                    Label(OrbixStrings.msgBrowseHot, systemImage: "flame.fill")
                    Text(OrbixStrings.msgSearchSuggestion)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await refreshSearch() }
    }

    // MARK: - Loading
    private var loadingView: some View {
        List {
            Section {
                loadingPlaceholderRows
            } header: {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(OrbixStrings.msgFetchingLatest)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Results
    private var displayResults: [ScrapedTorrent] {
        showingBookmarks ? results.filter { bookmarks.contains($0.code) } : results
    }

    private var sections: [(date: String, items: [ScrapedTorrent])] {
        let grouped = Dictionary(grouping: displayResults, by: { $0.date })
        return grouped.keys.sorted(by: >).compactMap { date in
            grouped[date].map { (date, $0) }
        }
    }

    private var resultsView: some View {
        List {
            if showingBookmarks && displayResults.isEmpty {
                ContentUnavailableView(OrbixStrings.msgNoBookmarked, systemImage: "heart.slash")
                    .listRowBackground(Color.clear)
            }

            ForEach(sections, id: \.date) { section in
                Section(section.date) {
                    torrentRows(section.items)
                }
            }

            if !results.isEmpty, !showingBookmarks {
                Section {
                    HStack {
                        Spacer()
                        if isLoadingMore {
                            ProgressView()
                        } else if hasMorePages {
                            Color.clear.frame(height: 1).onAppear { loadMore() }
                        } else {
                            Text(OrbixStrings.msgAllLoaded)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await refreshSearch() }
        .animation(.none, value: results.count)
    }

    // MARK: - Rows

    @ViewBuilder
    private func torrentRows(_ items: [ScrapedTorrent]) -> some View {
        ForEach(items) { torrent in
            ScrapedTorrentRow(torrent: torrent, isBookmarked: bookmarks.contains(torrent.code))
                .contentShape(Rectangle())
                .onTapGesture { selectedTorrent = torrent }
                .contextMenu { cardContextMenu(torrent) }
        }
    }

    // MARK: - Loading Placeholder
    private var loadingPlaceholderRows: some View {
        ForEach(0..<6, id: \.self) { _ in
            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(width: 52, height: 52)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Placeholder Title")
                    Text("Placeholder subtitle text")
                        .font(.footnote)
                }
                Spacer()
            }
            .redacted(reason: .placeholder)
        }
    }

    // MARK: - Context Menu
    private func cardContextMenu(_ torrent: ScrapedTorrent) -> some View {
        Group {
            Button { addMagnet(torrent) } label: { Label(OrbixStrings.btnAddToQueue, systemImage: "square.and.arrow.down") }
            Button { toggleBookmark(torrent) } label: {
                Label(bookmarks.contains(torrent.code) ? OrbixStrings.miscUnbookmark : OrbixStrings.miscBookmark,
                      systemImage: bookmarks.contains(torrent.code) ? "heart.fill" : "heart")
            }
            Button { translateCard(torrent) } label: { Label(String(localized: "一键翻译", comment: ""), systemImage: "translate") }
            Button { showVideoSubtitle = true } label: { Label(String(localized: "提取字幕", comment: ""), systemImage: "waveform") }
            Button { UIPasteboard.general.string = torrent.magnet } label: { Label(OrbixStrings.btnCopyMagnet, systemImage: "doc.on.doc") }
        }
    }

    // MARK: - Data
    private func loadLatest() {
        Task {
            state = .loading
            currentPage = 5
            hasMorePages = true
            do {
                let items = try await TorrentSearchService.shared.newTorrents(pages: 5, startPage: 1)
                await MainActor.run {
                    allResults = items
                    results = items
                    lastLoadTime = Date()
                    state = items.isEmpty ? .idle : .results
                }
            } catch {
                await MainActor.run { state = .idle }
            }
        }
    }

    private func debounceSearch() {
        searchTask?.cancel()
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []
            allResults = []
            showingBookmarks = false
            loadLatest()
            return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            if !Task.isCancelled { await runSearch() }
        }
    }

    private func runSearch() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { await MainActor.run { state = .idle }; return }

        await MainActor.run { state = .loading; hasMorePages = true }
        do {
            let items = try await TorrentSearchService.shared.search(query: q, pages: 5, startPage: 1)
            await MainActor.run {
                allResults = items
                results = items
                currentPage = 5
                lastLoadTime = Date()
                state = items.isEmpty ? .empty : .results
            }
        } catch {
            await MainActor.run { state = .error(error.localizedDescription) }
        }
    }

    @Sendable private func refreshSearch() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        do {
            let items: [ScrapedTorrent]
            if q.isEmpty {
                items = try await TorrentSearchService.shared.newTorrents(pages: 5, startPage: 1)
            } else {
                items = try await TorrentSearchService.shared.search(query: q, pages: 5, startPage: 1)
            }
            await MainActor.run {
                let existingCodes = Set(results.map(\.code))
                let newItems = items.filter { !existingCodes.contains($0.code) }
                var t = Transaction()
                t.disablesAnimations = true
                withTransaction(t) {
                    if !newItems.isEmpty {
                        results = newItems + results
                        allResults = newItems + allResults
                    }
                    lastLoadTime = Date()
                    currentPage = 5
                    hasMorePages = true
                }
            }
        } catch {
#if DEBUG
            print("[SearchView] refreshSearch error: \(error)")
#endif
        }
    }

    private func loadMore() {
        guard !isLoadingMore, hasMorePages else { return }
        isLoadingMore = true
        let q = query.trimmingCharacters(in: .whitespaces)
        let nextPage = currentPage + 1
        Task {
            do {
                let items: [ScrapedTorrent]
                if q.isEmpty {
                    items = try await TorrentSearchService.shared.newTorrents(pages: 1, startPage: nextPage)
                } else {
                    items = try await TorrentSearchService.shared.search(query: q, pages: 1, startPage: nextPage)
                }
                await MainActor.run {
                    if items.isEmpty {
                        hasMorePages = false
                    } else {
                        let existingCodes = Set(results.map(\.code))
                        let newItems = items.filter { !existingCodes.contains($0.code) }
                        if newItems.isEmpty {
                            hasMorePages = false
                        } else {
                            allResults.append(contentsOf: newItems)
                            results.append(contentsOf: newItems)
                            currentPage = nextPage
                        }
                    }
                    isLoadingMore = false
                }
            } catch {
                await MainActor.run { isLoadingMore = false }
            }
        }
    }

    private func addMagnet(_ torrent: ScrapedTorrent) {
        Task { try? await QBitApi.shared.addMagnet([torrent.magnet]) }
    }

    private func exportSRT() {
        guard let text = translatedText, !text.isEmpty else { return }
        let srt = "1\n00:00:00,000 --> 10:00:00,000\n\(text)\n"
        let fileName = "translation.srt"
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)
        do {
            try srt.write(to: fileURL, atomically: true, encoding: .utf8)
            exportedFileURL = fileURL
            showExportSheet = true
        } catch {}
    }

    private func toggleBookmark(_ torrent: ScrapedTorrent) {
        if bookmarks.contains(torrent.code) { bookmarks.remove(torrent.code) }
        else { bookmarks.insert(torrent.code) }
        saveBookmarks()
    }

    private func translateCard(_ torrent: ScrapedTorrent) {
        guard translatingCode == nil else { return }
        let sourceText = [torrent.title, torrent.description].compactMap { $0 }.filter { !$0.isEmpty }.first
        guard let text = sourceText else { return }

        translatingCode = torrent.code
        AppHaptics.medium()
        Task {
            do {
                let result = try await DeepSeekTranslateService.shared.translateToChinese(text)
                await MainActor.run {
                    translatingCode = nil
                    translatedText = result
                    showTranslation = true
                    AppHaptics.success()
                }
            } catch {
                await MainActor.run {
                    translatingCode = nil
                }
            }
        }
    }

    private func loadBookmarks() {
        bookmarks = Set(PersistenceService.shared.loadBookmarks())
    }

    private func saveBookmarks() {
        PersistenceService.shared.saveBookmarks(Array(bookmarks))
    }

    // MARK: - Empty / Error
    private func emptyHint(_ text: String, icon: String, isError: Bool = false) -> some View {
        ContentUnavailableView {
            Label(text, systemImage: icon)
        }
    }
}

#if DEBUG
#Preview {
    SearchView()
}
#endif
