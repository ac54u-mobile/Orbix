import SwiftUI

struct RadarrMovieDetailSheet: View {
    let movie: RadarrMovie
    @Environment(\.dismiss) private var dismiss

    @State private var isSearchingReleases = false
    @State private var releases: [RadarrRelease]?
    @State private var releaseError: String?
    @State private var addingGuid: String?
    @State private var addedGuids: Set<String> = []
    @State private var showAddedToast = false
    @State private var errorMessage: String?
    @State private var showErrorToast = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    coverSection
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                headerSection

                releasesSection

                if let overview = movie.overview, !overview.isEmpty {
                    Section(String(localized: "简介", comment: "Overview")) {
                        Text(overview)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }

                infoSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle(movie.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(OrbixStrings.btnClose) { dismiss() }
                }
            }
        }
        .toast(isPresented: $showAddedToast, type: .success, message: String(localized: "已添加到下载队列", comment: "Added to download queue"))
        .toast(isPresented: $showErrorToast, type: .error, message: errorMessage ?? String(localized: "操作失败", comment: "Operation failed"))
    }

    // MARK: - Cover

    @ViewBuilder
    private var coverSection: some View {
        if let poster = movie.posterURL, let url = URL(string: poster) {
            AsyncImage(url: url) { phase in
                if case .success(let img) = phase {
                    img.resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                } else {
                    placeholderCover
                }
            }
        } else {
            placeholderCover
        }
    }

    private var placeholderCover: some View {
        ZStack {
            Color(.secondarySystemGroupedBackground)
            Image(systemName: "film")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
        }
        .frame(height: 200)
    }

    // MARK: - Header

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(movie.title)
                    .font(.title3.bold())

                if let original = movie.originalTitle, original != movie.title {
                    Text(original)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 16) {
                    Label(String(movie.year), systemImage: "calendar")
                    if let rating = movie.ratingValue, rating > 0 {
                        Label(String(format: "%.1f", rating), systemImage: "star.fill")
                    }
                    if let runtime = movie.runtime, runtime > 0 {
                        Label("\(runtime) min", systemImage: "clock")
                    }
                }
                .font(.footnote)
                .foregroundStyle(.tertiary)

                if let genres = movie.genres, !genres.isEmpty {
                    Text(genres.joined(separator: " · "))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Releases

    private var releasesSection: some View {
        Section {
            if let releases {
                if releases.isEmpty {
                    ContentUnavailableView {
                        Label(String(localized: "未找到可下载资源", comment: "No releases found"), systemImage: "magnifyingglass")
                    } description: {
                        Text(String(localized: "各索引器均无该电影的资源", comment: "No releases description"))
                    }
                } else {
                    ForEach(releases) { release in
                        releaseRow(release)
                    }
                }
            } else {
                Button {
                    searchReleases()
                } label: {
                    HStack {
                        Label(String(localized: "搜索下载资源", comment: "Search releases"), systemImage: "magnifyingglass")
                            .fontWeight(.semibold)
                        Spacer()
                        if isSearchingReleases {
                            ProgressView()
                        }
                    }
                }
                .disabled(isSearchingReleases)

                if let releaseError {
                    Label(releaseError, systemImage: "xmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        } header: {
            if let releases, !releases.isEmpty {
                Text(String(format: OrbixStrings.miscCountResults, releases.count))
            }
        } footer: {
            if releases == nil {
                Text(isSearchingReleases
                     ? String(localized: "正在通过 Radarr 的索引器搜索，可能需要几十秒…", comment: "Searching releases hint")
                     : String(localized: "通过 Radarr 的索引器搜索资源，选择后直接添加到本机下载队列", comment: "Release search footer"))
            }
        }
    }

    private func releaseRow(_ release: RadarrRelease) -> some View {
        Button {
            addToQueue(release)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(release.title)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    HStack(spacing: 10) {
                        if let quality = release.qualityName, !quality.isEmpty {
                            Text(quality)
                                .fontWeight(.semibold)
                                .foregroundStyle(.blue)
                        }
                        if let size = release.size, size > 0 {
                            Text(formatBytes(size))
                        }
                        if let seeders = release.seeders {
                            HStack(spacing: 2) {
                                Image(systemName: "arrow.up")
                                Text("\(seeders)")
                            }
                            .foregroundStyle(seeders > 0 ? Color.green : Color.secondary)
                        }
                        if let indexer = release.indexer, !indexer.isEmpty {
                            Text(indexer)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                if addingGuid == release.guid {
                    ProgressView()
                        .controlSize(.small)
                } else if addedGuids.contains(release.guid) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "icloud.and.arrow.down")
                        .foregroundStyle(.blue)
                }
            }
        }
        .disabled(addingGuid != nil || addedGuids.contains(release.guid))
    }

    // MARK: - Info

    private var infoSection: some View {
        Section {
            LabeledContent("TMDB ID") {
                Text(String(movie.tmdbId)).monospacedDigit()
            }
            if let studio = movie.studio, !studio.isEmpty {
                LabeledContent(String(localized: "制片", comment: "Studio"), value: studio)
            }
        }
    }

    // MARK: - Search Releases

    private func searchReleases() {
        isSearchingReleases = true
        releaseError = nil
        AppHaptics.light()
        Task {
            do {
                let movieId = try await RadarrApi.shared.ensureInLibrary(movie)
                let found = try await RadarrApi.shared.releases(movieId: movieId)
                await MainActor.run {
                    releases = found
                        .filter { $0.downloadLink != nil }
                        .sorted { ($0.seeders ?? 0) > ($1.seeders ?? 0) }
                    isSearchingReleases = false
                }
            } catch {
                await MainActor.run {
                    isSearchingReleases = false
                    releaseError = error.localizedDescription
                    AppHaptics.error()
                }
            }
        }
    }

    // MARK: - Add to Queue

    private func addToQueue(_ release: RadarrRelease) {
        guard let link = release.downloadLink else { return }
        addingGuid = release.guid
        AppHaptics.medium()
        Task {
            do {
                _ = try await QBitApi.shared.addMagnet([link])
                await MainActor.run {
                    addingGuid = nil
                    addedGuids.insert(release.guid)
                    AppHaptics.success()
                    showAddedToast = true
                }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run { showAddedToast = false }
            } catch {
                await MainActor.run {
                    addingGuid = nil
                    errorMessage = error.localizedDescription
                    AppHaptics.error()
                    showErrorToast = true
                }
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                await MainActor.run { showErrorToast = false }
            }
        }
    }
}
