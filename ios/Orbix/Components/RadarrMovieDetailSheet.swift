import SwiftUI

struct RadarrMovieDetailSheet: View {
    let movie: RadarrMovie
    @Environment(\.dismiss) private var dismiss

    @State private var isAdding = false
    @State private var addedSuccess = false
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

                actionSection

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
        .toast(isPresented: $showAddedToast, type: .success, message: String(localized: "已添加，Radarr 开始自动搜索资源", comment: "Added to Radarr"))
        .toast(isPresented: $showErrorToast, type: .error, message: errorMessage ?? String(localized: "添加失败", comment: "Add failed"))
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

    // MARK: - Actions

    private var actionSection: some View {
        Section {
            if movie.isInLibrary || addedSuccess {
                Label(
                    movie.hasFile == true
                        ? String(localized: "已下载入库", comment: "Downloaded")
                        : String(localized: "已在 Radarr 片库，等待/搜索资源中", comment: "In Radarr library"),
                    systemImage: movie.hasFile == true ? "checkmark.circle.fill" : "bookmark.fill"
                )
                .foregroundStyle(movie.hasFile == true ? .green : .blue)
            } else {
                Button {
                    addToRadarr()
                } label: {
                    HStack {
                        Label(String(localized: "添加到 Radarr 并搜索资源", comment: "Add to Radarr and search"), systemImage: "plus.circle.fill")
                            .fontWeight(.semibold)
                        Spacer()
                        if isAdding {
                            ProgressView()
                        }
                    }
                }
                .disabled(isAdding)
            }
        } footer: {
            if !movie.isInLibrary && !addedSuccess {
                Text(String(localized: "Radarr 会按你服务器上配置的质量与索引器自动搜索并下载最佳资源", comment: "Radarr add footer"))
            }
        }
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

    // MARK: - Add

    private func addToRadarr() {
        isAdding = true
        Task {
            do {
                async let profiles = RadarrApi.shared.qualityProfiles()
                async let folders = RadarrApi.shared.rootFolders()
                guard let profile = try await profiles.first, let folder = try await folders.first else {
                    throw RadarrApi.RadarrError.noDefaults
                }
                try await RadarrApi.shared.addMovie(movie, qualityProfileId: profile.id, rootFolderPath: folder.path)
                await MainActor.run {
                    isAdding = false
                    addedSuccess = true
                    AppHaptics.success()
                    showAddedToast = true
                }
            } catch {
                await MainActor.run {
                    isAdding = false
                    errorMessage = error.localizedDescription
                    AppHaptics.error()
                    showErrorToast = true
                }
            }
        }
    }
}
