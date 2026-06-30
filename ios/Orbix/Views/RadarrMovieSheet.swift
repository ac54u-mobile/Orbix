import SwiftUI

struct RadarrMovieSheet: View {
    let item: SearchResult
    let qualityProfiles: [RadarrApi.QualityProfile]
    let rootFolders: [RadarrApi.RootFolder]

    @State private var releases: [MovieRelease] = []
    @State private var isLoading = true
    @State private var sort: MovieReleaseSort = .init()
    @State private var showAddToLibrary = false
    @State private var downloadingGuid: String?

    @Environment(\.dismiss) private var dismiss

    private var sortedReleases: [MovieRelease] {
        let sorted = releases.sorted { a, b in
            switch sort.option {
            case .bySeeders:
                return (a.seeders ?? 0) > (b.seeders ?? 0)
            case .bySize:
                return a.size > b.size
            case .byQuality:
                return a.qualityWeight > b.qualityWeight
            case .byAge:
                return a.age < b.age
            }
        }
        return sort.ascending ? sorted.reversed() : sorted
    }

    private var indexers: [String] {
        Array(Set(releases.compactMap { $0.indexer })).sorted()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerSection

                if isLoading {
                    Spacer()
                    ProgressView().tint(AppColors.accent)
                    Text(String(localized: "正在搜索 Release..."))
                        .subtitle()
                        .padding(.top, 8)
                    Spacer()
                } else if releases.isEmpty {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: "slash.circle")
                            .font(.system(size: 40, weight: .light))
                            .foregroundColor(AppColors.tertiaryLabel)
                        Text(String(localized: "未找到可用 Release"))
                            .subtitle()
                        Text(String(localized: "Radarr 索引器未返回结果，请检查索引器配置"))
                            .caption()
                    }
                    Spacer()
                } else {
                    sortBar
                    releaseList
                }

                Divider().background(AppColors.separator)

                addToLibraryButton
            }
            .background(AppColors.mainBg)
            .navigationTitle(item.fileName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(String(localized: "关闭")) { dismiss() }
                        .foregroundColor(AppColors.secondaryLabel)
                }
            }
            .task { await loadReleases() }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 14) {
            AsyncImage(url: URL(string: item.siteUrl)) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().aspectRatio(contentMode: .fill)
                default:
                    ZStack {
                        AppColors.card
                        Image(systemName: "film")
                            .foregroundColor(AppColors.tertiaryLabel.opacity(0.5))
                            .font(.system(size: 28))
                    }
                }
            }
            .frame(width: 64, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.fileName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.label)
                    .lineLimit(2)
                Text(String(format: String(localized: "TMDB: %d"), item.num))
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.tertiaryLabel)
                Text(String(format: String(localized: "%d 个 Release"), releases.count))
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.secondaryLabel)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 0)
                .fill(AppColors.card)
        )
    }

    // MARK: - Sort

    private var sortBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Menu {
                    Picker(String(localized: "排序"), selection: $sort.option) {
                        ForEach(MovieReleaseSort.Option.allCases) { opt in
                            Text(opt.label).tag(opt)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 11))
                        Text(sort.option.label)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(AppColors.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(AppColors.accent.opacity(0.1))
                    )
                }

                Button {
                    sort.ascending.toggle()
                } label: {
                    Image(systemName: sort.ascending ? "arrow.up" : "arrow.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppColors.accent)
                        .padding(7)
                        .background(
                            Circle().fill(AppColors.accent.opacity(0.1))
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Release List

    private var releaseList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(sortedReleases) { release in
                    releaseRow(release)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private func releaseRow(_ release: MovieRelease) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(release.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(release.rejected ? AppColors.tertiaryLabel : AppColors.label)
                        .lineLimit(2)

                    HStack(spacing: 12) {
                        Label(release.qualityLabel, systemImage: "film.stack")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppColors.secondaryLabel)
                        Label(release.sizeLabel, systemImage: "internaldrive")
                            .font(.system(size: 11))
                            .foregroundColor(AppColors.secondaryLabel)
                        Label(release.ageLabel, systemImage: "clock")
                            .font(.system(size: 11))
                            .foregroundColor(AppColors.secondaryLabel)
                    }
                }
                Spacer()

                Button {
                    downloadRelease(release)
                } label: {
                    if downloadingGuid == release.guid {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(AppColors.accent)
                    } else {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(AppColors.accent)
                    }
                }
                .disabled(downloadingGuid != nil || release.rejected)
            }

            HStack(spacing: 12) {
                Label(release.indexerLabel, systemImage: "building.2")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppColors.tertiaryLabel)

                Spacer()

                if let s = release.seeders {
                    Label("\(s)", systemImage: "arrow.up.circle.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppColors.success)
                }
                if let l = release.leechers {
                    Label("\(l)", systemImage: "arrow.down.circle.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppColors.danger)
                }

                if release.rejected {
                    Text(String(localized: "已拒绝"))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppColors.warning)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(AppColors.warning.opacity(0.15))
                        )
                }
            }

            if !release.downloadAllowed {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.warning)
                    Text(String(localized: "可能无法自动导入，将强制抓取"))
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.warning)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                        .stroke(AppColors.glassBorder, lineWidth: 0.5)
                )
        )
    }

    // MARK: - Add to Library

    private var addToLibraryButton: some View {
        Button {
            showAddToLibrary = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle")
                Text(String(localized: "添加到 Radarr 库"))
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(AppColors.secondaryLabel)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .sheet(isPresented: $showAddToLibrary) {
            QBitRadarrAddSheet(item: item, qualityProfiles: qualityProfiles, rootFolders: rootFolders)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Data

    private func loadReleases() async {
        do {
            releases = try await RadarrApi.lookupReleases(movieId: item.num)
        } catch {
#if DEBUG
            print("[RadarrMovieSheet] loadReleases error: \(error)")
#endif
        }
        await MainActor.run { isLoading = false }
    }

    private func downloadRelease(_ release: MovieRelease) {
        downloadingGuid = release.guid
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        Task {
            do {
                try await RadarrApi.downloadRelease(
                    guid: release.guid,
                    indexerId: release.indexerId,
                    movieId: release.downloadAllowed ? nil : item.num
                )
                await MainActor.run {
                    downloadingGuid = nil
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    ToastManager.shared.show(String(format: String(localized: "已抓取: %@"), release.title))
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    downloadingGuid = nil
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    ToastManager.shared.show(String(format: String(localized: "抓取失败: %@"), error.localizedDescription))
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    RadarrMovieSheet(
        item: SearchResult(num: 12345, descr: "", fileName: "The Matrix (1999)", fileSize: 0, nbLeechers: 0, nbSeeders: 0, siteUrl: ""),
        qualityProfiles: [],
        rootFolders: []
    )
}
#endif
