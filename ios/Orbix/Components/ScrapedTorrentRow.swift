import SwiftUI

struct ScrapedTorrentRow: View {
    let torrent: ScrapedTorrent
    let isBookmarked: Bool
    @State private var loadedThumbnail: UIImage?

    var body: some View {
        HStack(spacing: 16) {
            // Thumbnail
            ZStack(alignment: .topLeading) {
                thumbnailView
                if isBookmarked {
                    Circle().fill(AppColors.danger).frame(width: 14, height: 14)
                        .overlay(Image(systemName: "heart.fill").font(.system(size: 7)).foregroundColor(.white))
                        .offset(x: -4, y: -4)
                }
            }

            // Text
            VStack(alignment: .leading, spacing: 3) {
                Text(torrent.code)
                    .font(AppTypography.titleSmall())
                    .foregroundColor(Color(.label))
                    .lineLimit(1)

                let subtitle = subtitleText
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(AppTypography.descriptionSmall())
                        .foregroundColor(Color(.secondaryLabel))
                        .lineLimit(2)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(.tertiaryLabel))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(Color.clear)
        .task(id: torrent.id) {
            guard let urlStr = torrent.thumbnail, let url = URL(string: urlStr) else {
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
            } catch {
#if DEBUG
                print("[ScrapedTorrentRow] thumbnail load error: \(error)")
#endif
            }
        }
    }

    private var subtitleText: String {
        var parts: [String] = []
        if !torrent.size.isEmpty { parts.append(torrent.size) }
        if !torrent.date.isEmpty { parts.append(torrent.date) }
        if let desc = torrent.description, !desc.isEmpty { parts.append(desc) }
        return parts.joined(separator: " / ")
    }

    private var thumbnailView: some View {
        Group {
            if let img = loadedThumbnail {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Color(.tertiarySystemFill)
                    Image(systemName: "photo")
                        .font(.system(size: 18))
                        .foregroundColor(Color(.tertiaryLabel))
                }
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 0) {
        ScrapedTorrentRow(
            torrent: ScrapedTorrent(
                code: "SSIS-001",
                title: "Sample Title",
                size: "5.2 GB",
                date: "2026-06-29",
                thumbnail: nil,
                magnet: "magnet:?xt=urn:btih:demo",
                torrentUrl: nil,
                pageUrl: nil,
                description: "Some description text here"
            ),
            isBookmarked: true
        )
        Divider().padding(.leading, 80)
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
    .background(Color.clear)
    .clipShape(RoundedRectangle(cornerRadius: 14))
    .padding(.horizontal, 16)
    .background(AppColors.backgroundBase)
}
#endif
