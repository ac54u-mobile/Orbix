import SwiftUI

struct TorrentDetailSheet: View {
    let torrent: ScrapedTorrent
    @Binding var bookmarks: Set<String>
    let onChanged: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var translatedDescription: String?
    @State private var showMediaViewer = false

    private var isBookmarked: Bool { bookmarks.contains(torrent.code) }

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

                if let desc = translatedDescription ?? torrent.description {
                    descriptionSection(desc)
                }

                infoSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle(torrent.code)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(OrbixStrings.btnClose) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { toggleBookmark() } label: {
                        Image(systemName: isBookmarked ? "heart.fill" : "heart")
                            .foregroundStyle(isBookmarked ? Color.red : Color.secondary)
                    }
                }
            }
        }
        .onAppear { translate() }
        .fullScreenCover(isPresented: $showMediaViewer) {
            if let thumb = torrent.thumbnail {
                MediaViewer(images: [thumb], initialIndex: 0)
            }
        }
    }

    // MARK: - Cover Image
    @ViewBuilder
    private var coverSection: some View {
        if let thumb = torrent.thumbnail {
            AsyncImage(url: URL(string: thumb)) { phase in
                switch phase {
                case .success(let img):
                    fullCover(img)
                case .failure:
                    // 主图源失效时尝试站点备用海报
                    if let fb = torrent.fallbackThumbnail, fb != thumb {
                        AsyncImage(url: URL(string: fb)) { fbPhase in
                            if case .success(let img) = fbPhase {
                                fullCover(img)
                            } else {
                                placeholderCover
                            }
                        }
                    } else {
                        placeholderCover
                    }
                default:
                    placeholderCover
                }
            }
        } else {
            placeholderCover
        }
    }

    /// 原图比例完整显示，不裁切
    private func fullCover(_ img: Image) -> some View {
        img.resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .overlay(alignment: .bottomLeading) {
                Text(torrent.size)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.55), in: Capsule())
                    .padding(12)
            }
            .onTapGesture { showMediaViewer = true }
    }

    private var placeholderCover: some View {
        ZStack {
            Color(.secondarySystemGroupedBackground)
            Image(systemName: "photo")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
        }
        .frame(height: 160)
    }

    // MARK: - Header
    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(torrent.code)
                    .font(.title3.bold())

                if torrent.title != torrent.code {
                    Text(torrent.title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                HStack(spacing: 16) {
                    Label(torrent.size, systemImage: "internaldrive")
                    Label(torrent.date, systemImage: "calendar")
                }
                .font(.footnote)
                .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Actions
    private var actionSection: some View {
        Section {
            Button {
                Task { _ = try? await QBitApi.shared.addMagnet([torrent.magnet]); dismiss() }
            } label: {
                Label(OrbixStrings.btnAddToQueue, systemImage: "square.and.arrow.down")
                    .fontWeight(.semibold)
            }

            Button {
                UIPasteboard.general.string = torrent.magnet
                AppHaptics.success()
            } label: {
                Label(OrbixStrings.btnCopyMagnet, systemImage: "doc.on.doc")
            }

            Button {
                UIPasteboard.general.string = torrent.code
                AppHaptics.success()
            } label: {
                Label(OrbixStrings.miscCode, systemImage: "number")
            }

            if let torrentUrl = torrent.torrentUrl {
                Button { downloadTorrent(torrentUrl) } label: {
                    Label(OrbixStrings.btnDownloadTorrent, systemImage: "arrow.down.doc")
                }
            }
        }
    }

    // MARK: - Description
    private func descriptionSection(_ desc: String) -> some View {
        Section(OrbixStrings.miscFilm) {
            Text(desc)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            if translatedDescription != nil, let raw = torrent.description {
                VStack(alignment: .leading, spacing: 6) {
                    Label(OrbixStrings.miscOriginalJP, systemImage: "textformat")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Text(raw)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
    }

    // MARK: - Info
    private var infoSection: some View {
        Section {
            infoRow(label: OrbixStrings.miscCode, value: torrent.code, copyValue: torrent.code)

            if let pageUrl = torrent.pageUrl {
                infoRow(label: OrbixStrings.miscPageLink, value: pageUrl, copyValue: pageUrl)
            }
        }
    }

    private func infoRow(label: String, value: String, copyValue: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    UIPasteboard.general.string = copyValue
                    AppHaptics.success()
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.footnote)
                }
                .buttonStyle(.borderless)
            }
            Text(value)
                .font(.system(.footnote, design: .monospaced))
                .lineLimit(2)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Actions (privates)
    private func toggleBookmark() {
        if bookmarks.contains(torrent.code) { bookmarks.remove(torrent.code) }
        else { bookmarks.insert(torrent.code) }
        onChanged()
    }

    private func translate() {
        guard let desc = torrent.description, !desc.isEmpty else { return }
        Task {
            let translated = try? await DeepSeekTranslateService.shared.translateToChinese(desc)
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
