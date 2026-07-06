import SwiftUI

struct ScrapedTorrentRow: View {
    let torrent: ScrapedTorrent
    let isBookmarked: Bool
    @State private var loadedThumbnail: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 完整海报 — 原图比例不裁切，对齐站点原版卡片
            ZStack(alignment: .topTrailing) {
                posterView
                if isBookmarked {
                    Circle().fill(Color.red).frame(width: 20, height: 20)
                        .overlay(Image(systemName: "heart.fill").font(.system(size: 10)).foregroundStyle(.white))
                        .padding(8)
                }
            }

            HStack(alignment: .firstTextBaseline) {
                Text(torrent.code)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                if !torrent.size.isEmpty {
                    Text(torrent.size)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if !torrent.date.isEmpty {
                Text(torrent.date)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let desc = torrent.description, !desc.isEmpty {
                Text(desc)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(torrent.code)
        .accessibilityValue(subtitleText)
        .accessibilityHint(String(localized: "Double-tap to view details"))
        .accessibilityAddTraits(isBookmarked ? .isSelected : [])
        .task(id: torrent.id) {
            await loadPoster()
        }
    }

    private var subtitleText: String {
        var parts: [String] = []
        if !torrent.size.isEmpty { parts.append(torrent.size) }
        if !torrent.date.isEmpty { parts.append(torrent.date) }
        if let desc = torrent.description, !desc.isEmpty { parts.append(desc) }
        return parts.joined(separator: " / ")
    }

    @ViewBuilder
    private var posterView: some View {
        if let img = loadedThumbnail {
            Image(uiImage: img)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(.tertiarySystemFill))
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 180)
        }
    }

    private func loadPoster() async {
        let candidates = [torrent.thumbnail, torrent.fallbackThumbnail].compactMap { $0 }.filter { !$0.isEmpty }
        guard !candidates.isEmpty else {
            loadedThumbnail = nil
            return
        }

        for urlStr in candidates {
            guard let url = URL(string: urlStr) else { continue }
            if let cached = ImageCache.shared.get(url.absoluteString) {
                loadedThumbnail = cached
                return
            }
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                if let http = response as? HTTPURLResponse, http.statusCode != 200 { continue }
                if let img = UIImage(data: data) {
                    ImageCache.shared.set(url.absoluteString, image: img)
                    loadedThumbnail = img
                    return
                }
            } catch {
#if DEBUG
                print("[ScrapedTorrentRow] poster load error: \(error)")
#endif
            }
        }
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
