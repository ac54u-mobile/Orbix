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

    enum SearchState { case idle, loading, results, empty, error(String) }

    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.gridBackgroundGradient.ignoresSafeArea()
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
                            .foregroundColor(AppColors.accentPrimary)
                            .font(.system(size: 14))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        AppHaptics.light()
                        withAnimation(.none) { showingBookmarks.toggle() }
                    } label: {
                        Image(systemName: showingBookmarks ? "heart.fill" : (bookmarks.isEmpty ? "heart" : "heart.fill"))
                            .foregroundColor(AppColors.accentPrimary)
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
            } message: {
                Text(translatedText ?? "")
            }
        }
    }

    // MARK: - Idle / Trending
    private var idleView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "flame.fill").foregroundColor(AppColors.warning)
                    Text(OrbixStrings.msgBrowseHot).sectionHeader()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Text(OrbixStrings.msgSearchSuggestion)
                    .descriptionSmall(AppColors.textTertiary)
                    .padding(.horizontal, 20)

                if results.isEmpty {
                    listSkeleton
                } else {
                    sectionGroup(results)
                }
            }
        }
        .refreshable { await refreshSearch() }
    }

    // MARK: - Loading
    private var loadingView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ProgressView().tint(AppColors.accentPrimary)
                Text(OrbixStrings.msgFetchingLatest).descriptionSmall(AppColors.textTertiary)
            }
            .padding(.top, 16)
            listSkeleton
        }
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
        ScrollView {
            if showingBookmarks && displayResults.isEmpty {
                VStack(spacing: 12) {
                    Spacer().frame(height: 80)
                    Image(systemName: "heart.slash")
                        .font(.system(size: 40))
                        .foregroundColor(AppColors.placeholder)
                    Text(OrbixStrings.msgNoBookmarked)
                        .foregroundColor(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }

            LazyVStack(spacing: 16) {
                ForEach(sections, id: \.date) { section in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(section.date)
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.horizontal, 20)
                        sectionGroup(section.items)
                    }
                }

                if !results.isEmpty, !showingBookmarks {
                    VStack(spacing: 4) {
                        if isLoadingMore {
                            ProgressView().tint(AppColors.accentPrimary)
                        } else if hasMorePages {
                            Color.clear.frame(height: 1).onAppear { loadMore() }
                        } else {
                            Text(OrbixStrings.msgAllLoaded)
                                .font(.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                    .padding(.vertical, 20)
                }
            }
            .padding(.top, 8)
        }
        .refreshable { await refreshSearch() }
        .animation(.none, value: results.count)
    }

    // MARK: - Grouped Section Container
    @ViewBuilder
    private func sectionGroup(_ items: [ScrapedTorrent]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { idx, torrent in
                ScrapedTorrentRow(torrent: torrent, isBookmarked: bookmarks.contains(torrent.code))
                    .contentShape(Rectangle())
                    .onTapGesture { selectedTorrent = torrent }
                    .contextMenu { cardContextMenu(torrent) }
                if idx < items.count - 1 {
                    Divider().padding(.leading, 80)
                }
            }
        }
        .background(Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: SettingsConfig.containerCornerRadius))
        .padding(.horizontal, 16)
    }

    // MARK: - Skeleton
    private var listSkeleton: some View {
        VStack(spacing: 0) {
            ForEach(0..<6, id: \.self) { i in
                HStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: AppRadius.sm)
                        .fill(Color(.tertiarySystemFill))
                        .frame(width: 52, height: 52)
                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.tertiarySystemFill))
                            .frame(height: 14).frame(maxWidth: 150)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.quaternarySystemFill))
                            .frame(height: 11).frame(maxWidth: 220)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(Color.clear)
                if i < 5 { Divider().padding(.leading, 80) }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: SettingsConfig.containerCornerRadius))
        .padding(.horizontal, 16)
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
        VStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 48))
                .foregroundColor(isError ? AppColors.danger : AppColors.placeholder)
            Text(text).descriptionSmall(isError ? AppColors.danger : AppColors.textSecondary)
        }
    }
}

#if DEBUG
#Preview {
    SearchView()
}
#endif
