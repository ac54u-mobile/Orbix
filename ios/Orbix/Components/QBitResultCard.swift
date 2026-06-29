import SwiftUI

struct QBitResultCard: View {
    let item: SearchResult
    let searchSource: SearchSource
    @Binding var selectedResult: SearchResult?
    @Binding var radarrResult: SearchResult?
    @Binding var qualityProfiles: [RadarrApi.QualityProfile]
    @Binding var rootFolders: [RadarrApi.RootFolder]
    @Binding var showRadarrSheet: Bool
    @Binding var showDownloadSheet: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 6) {
                Text(item.fileName)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(item.isAdded ? AppColors.secondaryLabel : AppColors.label)
                    .lineLimit(2)
                if item.isAdded {
                    Text(OrbixStrings.miscInLibrary)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppColors.success)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: AppRadius.xs)
                                .fill(AppColors.success.opacity(0.12))
                        )
                }
            }

            HStack(spacing: 16) {
                Label(formatBytes(Int64(item.fileSize)), systemImage: "internaldrive")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.secondaryLabel)

                if item.nbSeeders > 0 {
                    Label("\(item.nbSeeders)", systemImage: "arrow.up.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppColors.success)
                }

                if item.nbLeechers > 0 {
                    Label("\(item.nbLeechers)", systemImage: "arrow.down.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppColors.danger)
                }

                Spacer()

                if item.isAdded {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.success.opacity(0.5))
                        .padding(8)
                        .background(
                            Circle().fill(AppColors.success.opacity(0.1))
                        )
                } else {
                    Button {
                        guard !showDownloadSheet, !showRadarrSheet else { return }
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        if searchSource == .radarr {
                            radarrResult = item
                            Task {
                                let p = (try? await RadarrApi.getQualityProfiles()) ?? []
                                let r = (try? await RadarrApi.getRootFolders()) ?? []
                                await MainActor.run {
                                    qualityProfiles = p
                                    rootFolders = r
                                    showRadarrSheet = true
                                }
                            }
                        } else {
                            selectedResult = item
                            showDownloadSheet = true
                        }
                    } label: {
                        Image(systemName: "icloud.and.arrow.down.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.accent)
                            .padding(8)
                            .background(
                                Circle().fill(AppColors.accent.opacity(0.1))
                            )
                    }
                }
            }

            if !item.siteUrl.isEmpty {
                Text(item.siteUrl)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(AppColors.tertiaryLabel)
                    .lineLimit(1)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                        .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 4)
        )
    }
}

#if DEBUG
struct QBitResultCardPreview: View {
    @State private var radarrResult: SearchResult?
    @State private var qualityProfiles: [RadarrApi.QualityProfile] = []
    @State private var rootFolders: [RadarrApi.RootFolder] = []
    @State private var showRadarrSheet = false
    @State private var showDownloadSheet = false
    @State private var selectedResult: SearchResult?

    var body: some View {
        QBitResultCard(
            item: .demo(),
            searchSource: .qBittorrent,
            selectedResult: $selectedResult,
            radarrResult: $radarrResult,
            qualityProfiles: $qualityProfiles,
            rootFolders: $rootFolders,
            showRadarrSheet: $showRadarrSheet,
            showDownloadSheet: $showDownloadSheet
        )
        .padding()
    }
}

#Preview {
    QBitResultCardPreview()
}
#endif
