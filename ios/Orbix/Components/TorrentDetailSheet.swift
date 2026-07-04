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
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    coverSection

                    headerSection

                    actionSection

                    if let desc = translatedDescription ?? torrent.description {
                        descriptionCard(desc)
                    }

                    infoCards
                }
                .padding(AppSpacing.lg)
                .padding(.bottom, 32)
            }
            .background(AppColors.gridBackgroundGradient)
            .navigationTitle(torrent.code)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(OrbixStrings.btnClose) { dismiss() }
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.accentPrimary)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { toggleBookmark() } label: {
                        Image(systemName: isBookmarked ? "heart.fill" : "heart")
                            .foregroundColor(isBookmarked ? AppColors.danger : AppColors.textTertiary)
                    }
                }
            }
        }
        .onAppear { translate() }
    }

    // MARK: - Cover Image
    private var coverSection: some View {
        Group {
            if let thumb = torrent.thumbnail {
                AsyncImage(url: URL(string: thumb)) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 240)
                            .clipped()
                            .overlay(coverGradient, alignment: .bottom)
                            .overlay(alignment: .bottomLeading) {
                                Text(torrent.size)
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, AppSpacing.sm)
                                    .padding(.vertical, AppSpacing.xs)
                                    .background(
                                        Capsule()
                                            .fill(.black.opacity(0.55))
                                    )
                                    .padding(AppSpacing.md)
                            }
                            .onTapGesture { showMediaViewer = true }
                    default:
                        placeholderCover
                    }
                }
            } else {
                placeholderCover
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
    }

    private var coverGradient: some View {
        LinearGradient(
            colors: [.clear, .black.opacity(0.5)],
            startPoint: .center,
            endPoint: .bottom
        )
    }

    private var placeholderCover: some View {
        ZStack {
            AppColors.card
            Image(systemName: "photo")
                .font(.system(size: 32))
                .foregroundColor(AppColors.placeholder)
        }
        .frame(height: 160)
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(torrent.code)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(AppColors.accentPrimary)

            if torrent.title != torrent.code {
                Text(torrent.title)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(3)
            }

            HStack(spacing: AppSpacing.lg) {
                Label(torrent.size, systemImage: "internaldrive")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textTertiary)

                Label(torrent.date, systemImage: "calendar")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(.top, AppSpacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .fill(AppColors.card)
        )
    }

    // MARK: - Actions
    private var actionSection: some View {
        VStack(spacing: AppSpacing.sm) {
            Button {
                Task { _ = try? await QBitApi.shared.addMagnet([torrent.magnet]); dismiss() }
            } label: {
                Label(OrbixStrings.btnAddToQueue, systemImage: "square.and.arrow.down")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                            .fill(AppColors.accentPrimary)
                    )
            }
            .buttonStyle(ScaleButtonStyle())

            HStack(spacing: AppSpacing.sm) {
                Button {
                    UIPasteboard.general.string = torrent.magnet
                    AppHaptics.success()
                } label: {
                    Label(OrbixStrings.btnCopyMagnet, systemImage: "doc.on.doc")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.accentPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                                .stroke(AppColors.accentPrimary, lineWidth: 1)
                        )
                }
                .buttonStyle(ScaleButtonStyle())

                Button {
                    UIPasteboard.general.string = torrent.code
                    AppHaptics.success()
                } label: {
                    Label(OrbixStrings.miscCode, systemImage: "number")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                                .stroke(AppColors.separator, lineWidth: 1)
                        )
                }
                .buttonStyle(ScaleButtonStyle())
            }

            if let torrentUrl = torrent.torrentUrl {
                Button { downloadTorrent(torrentUrl) } label: {
                    Label(OrbixStrings.btnDownloadTorrent, systemImage: "arrow.down.doc")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.accentPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                                .stroke(AppColors.accentPrimary, lineWidth: 1)
                        )
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }

    // MARK: - Description
    private func descriptionCard(_ desc: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.textTertiary)
                Text(OrbixStrings.miscFilm)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppColors.textTertiary)
            }

            Text(desc)
                .font(.system(size: 14))
                .foregroundColor(AppColors.textSecondary)
                .textSelection(.enabled)

            if translatedDescription != nil, let raw = torrent.description {
                Divider()
                    .background(AppColors.separator)

                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "textformat")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.textTertiary)
                    Text(OrbixStrings.miscOriginalJP)
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textTertiary)
                }

                Text(raw)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
                    .textSelection(.enabled)
            }
        }
        .padding(AppSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .fill(AppColors.card)
        )
    }

    // MARK: - Info Cards
    private var infoCards: some View {
        VStack(spacing: AppSpacing.sm) {
            infoRow(icon: "number", label: OrbixStrings.miscCode, value: torrent.code, copyValue: torrent.code)

            if let pageUrl = torrent.pageUrl {
                infoRow(icon: "link", label: OrbixStrings.miscPageLink, value: pageUrl, copyValue: pageUrl, monospacedSize: 11)
            }
        }
    }

    private func infoRow(icon: String, label: String, value: String, copyValue: String, monospacedSize: CGFloat = 13) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(AppColors.textTertiary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppColors.textTertiary)
                Text(value)
                    .font(.system(size: monospacedSize, design: .monospaced))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)
            }

            Spacer()

            Button {
                UIPasteboard.general.string = copyValue
                AppHaptics.success()
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.accentPrimary)
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                .fill(AppColors.card)
        )
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
