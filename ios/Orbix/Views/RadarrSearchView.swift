import SwiftUI

struct RadarrSearchView: View {
    @State private var query = ""
    @State private var movies: [RadarrMovie] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedMovie: RadarrMovie?
    @State private var searchTask: Task<Void, Never>?
    @State private var isConfigured = RadarrConfig.load().isConfigured

    var body: some View {
        NavigationStack {
            Group {
                if !isConfigured {
                    ContentUnavailableView {
                        Label(String(localized: "未配置 Radarr", comment: "Radarr not configured"), systemImage: "film.stack")
                    } description: {
                        Text(String(localized: "请到 设置 → Radarr 填写服务器地址和 API Key", comment: "Configure Radarr hint"))
                    }
                } else if isLoading && movies.isEmpty {
                    ProgressView(String(localized: "正在搜索电影…", comment: "Searching movies"))
                } else if let error = errorMessage {
                    ContentUnavailableView {
                        Label(String(localized: "搜索失败", comment: "Search failed"), systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    }
                } else if query.isEmpty {
                    ContentUnavailableView {
                        Label(String(localized: "搜索电影", comment: "Search movies"), systemImage: "film")
                    } description: {
                        Text(String(localized: "输入电影名称，通过 Radarr 搜索资源", comment: "Radarr search hint"))
                    }
                } else if movies.isEmpty && !isLoading {
                    ContentUnavailableView.search(text: query)
                } else {
                    movieList
                }
            }
            .navigationTitle("Radarr")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    SearchSourceMenu()
                }
            }
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: Text(String(localized: "电影名称", comment: "Movie name"))
            )
            .onChange(of: query) { _, _ in debounceSearch() }
            .onAppear { isConfigured = RadarrConfig.load().isConfigured }
            .sheet(item: $selectedMovie) { movie in
                RadarrMovieDetailSheet(movie: movie)
            }
        }
    }

    // MARK: - List

    private var movieList: some View {
        List {
            Section {
                ForEach(movies) { movie in
                    Button {
                        AppHaptics.light()
                        selectedMovie = movie
                    } label: {
                        MovieRow(movie: movie)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text(String(format: OrbixStrings.miscCountResults, movies.count))
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Search

    private func debounceSearch() {
        searchTask?.cancel()
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else {
            movies = []
            errorMessage = nil
            isLoading = false
            return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            await runSearch(q)
        }
    }

    private func runSearch(_ term: String) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        do {
            let found = try await RadarrApi.shared.lookup(term)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                movies = found
                isLoading = false
            }
        } catch {
            guard !Task.isCancelled else { return }
            await MainActor.run {
                movies = []
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

// MARK: - Movie Row

private struct MovieRow: View {
    let movie: RadarrMovie

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            posterThumb

            VStack(alignment: .leading, spacing: 4) {
                Text(movie.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)

                HStack(spacing: 10) {
                    Text(String(movie.year))
                    if let rating = movie.ratingValue, rating > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.yellow)
                            Text(String(format: "%.1f", rating))
                        }
                    }
                    if let runtime = movie.runtime, runtime > 0 {
                        Text("\(runtime) min")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let genres = movie.genres, !genres.isEmpty {
                    Text(genres.prefix(3).joined(separator: " · "))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                if movie.isInLibrary {
                    Label(
                        movie.hasFile == true
                            ? String(localized: "已入库", comment: "Downloaded")
                            : String(localized: "已在 Radarr", comment: "In Radarr"),
                        systemImage: movie.hasFile == true ? "checkmark.circle.fill" : "bookmark.fill"
                    )
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(movie.hasFile == true ? .green : .blue)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .padding(.top, 6)
        }
        .padding(.vertical, 4)
    }

    private var posterThumb: some View {
        AsyncImage(url: movie.posterURL.flatMap { URL(string: $0) }) { phase in
            if case .success(let img) = phase {
                img.resizable().aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Color(.tertiarySystemFill)
                    Image(systemName: "film")
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(width: 56, height: 84)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

#if DEBUG
#Preview {
    RadarrSearchView()
}
#endif
