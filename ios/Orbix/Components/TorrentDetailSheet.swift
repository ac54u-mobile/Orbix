import SwiftUI

struct TorrentDetailSheet: View {
    let torrent: ScrapedTorrent
    @Binding var bookmarks: Set<String>
    let onChanged: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var translatedDescription: String?
    @State private var showMediaViewer = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let thumb = torrent.thumbnail {
                        AsyncImage(url: URL(string: thumb)) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable().aspectRatio(contentMode: .fit).frame(maxHeight: 250)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .onTapGesture { showMediaViewer = true }
                            default:
                                Rectangle().fill(AppColors.card).frame(height: 200)
                            }
                        }
                    }

                    Text(torrent.code).cardTitle()
                    if torrent.title != torrent.code {
                        Text(torrent.title).subtitle(AppColors.tertiaryLabel)
                    }

                    HStack(spacing: 16) {
                        Label(torrent.size, systemImage: "doc").caption()
                        Label(torrent.date, systemImage: "calendar").caption()
                    }

                    if let desc = translatedDescription ?? torrent.description {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(desc).subtitle().textSelection(.enabled)
                            if translatedDescription != nil, let raw = torrent.description {
                                Divider().background(AppColors.separator)
                                HStack {
                                    Image(systemName: "doc.text").font(.caption2).foregroundColor(AppColors.tertiaryLabel)
                                    Text(OrbixStrings.miscOriginalJP).font(.caption2).foregroundColor(AppColors.tertiaryLabel)
                                }
                                Text(raw).subtitle().textSelection(.enabled)
                            }
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.card))
                    }

                    VStack(spacing: 12) {
                        VStack(spacing: 4) {
                            HStack {
                                Image(systemName: "tag").font(.caption2).foregroundColor(AppColors.tertiaryLabel)
                                Text(OrbixStrings.miscCode).font(.caption2).foregroundColor(AppColors.tertiaryLabel)
                                Spacer()
                            }
                            HStack {
                                Text(torrent.code).font(.system(size: 13, design: .monospaced)).foregroundColor(AppColors.label)
                                Spacer()
                                Button { UIPasteboard.general.string = torrent.code } label: {
                                    Image(systemName: "doc.on.doc").font(.caption2).foregroundColor(AppColors.accent)
                                }
                            }
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.card))

                        if let pageUrl = torrent.pageUrl {
                            VStack(spacing: 4) {
                                HStack {
                                    Image(systemName: "link").font(.caption2).foregroundColor(AppColors.tertiaryLabel)
                                    Text(OrbixStrings.miscPageLink).font(.caption2).foregroundColor(AppColors.tertiaryLabel)
                                    Spacer()
                                }
                                HStack {
                                    Text(pageUrl).font(.system(size: 11, design: .monospaced)).foregroundColor(AppColors.accent).lineLimit(1)
                                    Spacer()
                                    Button { UIPasteboard.general.string = pageUrl } label: {
                                        Image(systemName: "doc.on.doc").font(.caption2).foregroundColor(AppColors.accent)
                                    }
                                }
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.card))
                        }
                    }

                    VStack(spacing: 10) {
                        Button {
                            Task { _ = try? await QBitApi.shared.addMagnet([torrent.magnet]); dismiss() }
                        } label: {
                            Label(OrbixStrings.btnAddToQueue, systemImage: "square.and.arrow.down")
                                .bodyFont(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.accent))
                        }

                        Button { UIPasteboard.general.string = torrent.magnet } label: {
                            Label(OrbixStrings.btnCopyMagnet, systemImage: "doc.on.doc")
                                .bodyFont(AppColors.accent).frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(RoundedRectangle(cornerRadius: 14).stroke(AppColors.accent, lineWidth: 1))
                        }

                        if let torrentUrl = torrent.torrentUrl {
                            Button { downloadTorrent(torrentUrl) } label: {
                                Label(OrbixStrings.btnDownloadTorrent, systemImage: "arrow.down.doc")
                                    .bodyFont(AppColors.accent).frame(maxWidth: .infinity).padding(.vertical, 12)
                                    .background(RoundedRectangle(cornerRadius: 14).stroke(AppColors.accent, lineWidth: 1))
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(AppColors.groupedBg)
            .navigationTitle(OrbixStrings.navDetails)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(OrbixStrings.btnClose) { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button { toggleBookmark() } label: {
                        Image(systemName: bookmarks.contains(torrent.code) ? "heart.fill" : "heart")
                            .foregroundColor(bookmarks.contains(torrent.code) ? AppColors.danger : AppColors.tertiaryLabel)
                    }
                }
            }
        }
        .onAppear { translate() }
    }

    private func toggleBookmark() {
        if bookmarks.contains(torrent.code) { bookmarks.remove(torrent.code) }
        else { bookmarks.insert(torrent.code) }
        onChanged()
    }

    private func translate() {
        guard let desc = torrent.description, !desc.isEmpty else { return }
        Task {
            let translated = try? await TranslateService.shared.toChinese(desc)
            await MainActor.run { translatedDescription = translated }
        }
    }

    private func downloadTorrent(_ urlStr: String) {
        guard let url = URL(string: urlStr.hasPrefix("http") ? urlStr : "https://www.141ppv.com\(urlStr)") else { return }
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let temp = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
                try data.write(to: temp)
                await MainActor.run {
                    let av = UIActivityViewController(activityItems: [temp], applicationActivities: nil)
                    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let root = scene.windows.first?.rootViewController {
                        root.present(av, animated: true)
                    }
                }
            } catch {
#if DEBUG
                print("[TorrentDetailSheet] download error: \(error)")
#endif
            }
    }
}

#if DEBUG
struct TorrentDetailSheetPreview: View {
    @State private var bookmarks: Set<String> = []

    var body: some View {
        TorrentDetailSheet(torrent: .demo(), bookmarks: $bookmarks, onChanged: {})
    }
}

#Preview {
    TorrentDetailSheetPreview()
}
#endif
