import SwiftUI

struct ScrapedTorrentRow: View {
    let torrent: ScrapedTorrent
    let isBookmarked: Bool
    @State private var loadedThumbnail: UIImage?

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            thumbnailView

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(torrent.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppColors.label)
                    .lineLimit(2)

                HStack(spacing: AppSpacing.sm) {
                    Text(torrent.code)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(AppColors.accent)

                    if !torrent.date.isEmpty {
                        Text(torrent.date)
                            .font(.system(size: 11))
                            .foregroundColor(AppColors.tertiaryLabel)
                    }

                    if !torrent.size.isEmpty {
                        Text(torrent.size)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(AppColors.secondaryLabel)
                    }
                }

                if isBookmarked {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.danger)
                        Text(OrbixStrings.miscBookmark)
                            .font(.system(size: 11))
                            .foregroundColor(AppColors.danger)
                    }
                }
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .fill(AppColors.card)
        )
        .task(id: torrent.id) {
            guard let urlStr = torrent.thumbnail,
                  let url = URL(string: urlStr) else {
                loadedThumbnail = nil
                return
            }
            if let cached = ImageCache.shared.get(url.absoluteString) {
                loadedThumbnail = cached
                return
            }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let img = UIImage(data: data) {
                    ImageCache.shared.set(url.absoluteString, image: img)
                    loadedThumbnail = img
                }
            } catch {}
        }
    }

    private var thumbnailView: some View {
        Group {
            if let img = loadedThumbnail {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    AppColors.elevated
                    Image(systemName: "photo")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.placeholder)
                }
            }
        }
        .frame(width: 60, height: 80)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
    }
}

#if DEBUG
#Preview {
    VStack(spacing: AppSpacing.sm) {
        ScrapedTorrentRow(
            torrent: ScrapedTorrent(
                code: "SSIS-001",
                title: "Sample Title That Is Quite Long And Might Span Multiple Lines",
                size: "5.2 GB",
                date: "2026-06-29",
                thumbnail: nil,
                magnet: "magnet:?xt=urn:btih:demo",
                torrentUrl: nil,
                pageUrl: nil,
                description: nil
            ),
            isBookmarked: true
        )
        ScrapedTorrentRow(
            torrent: ScrapedTorrent(
                code: "ABW-123",
                title: "Short Title",
                size: "1.8 GB",
                date: "2026-06-28",
                thumbnail: nil,
                magnet: "magnet:?xt=urn:btih:demo2",
                torrentUrl: nil,
                pageUrl: nil,
                description: nil
            ),
            isBookmarked: false
        )
    }
    .padding(.horizontal, AppSpacing.lg)
    .background(AppColors.mainBg)
}
#endif
