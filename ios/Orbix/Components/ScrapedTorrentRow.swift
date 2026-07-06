import SwiftUI

struct ScrapedTorrentRow: View {
    let torrent: ScrapedTorrent
    let isBookmarked: Bool
    @State private var loadedThumbnail: UIImage?

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            ZStack(alignment: .topLeading) {
                thumbnailView
                if isBookmarked {
                    Circle().fill(Color.red).frame(width: 14, height: 14)
                        .overlay(Image(systemName: "heart.fill").font(.system(size: 7)).foregroundStyle(.white))
                        .offset(x: -4, y: -4)
                }
            }

            // Text
            VStack(alignment: .leading, spacing: 3) {
                Text(torrent.code)
                    .font(.headline)
                    .lineLimit(1)

                let subtitle = subtitleText
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(torrent.code)
        .accessibilityValue(subtitleText)
        .accessibilityHint(String(localized: "Double-tap to view details"))
        .accessibilityAddTraits(isBookmarked ? .isSelected : [])
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
                        .font(.body)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
    .padding(.horizontal, 16)
}
#endif
