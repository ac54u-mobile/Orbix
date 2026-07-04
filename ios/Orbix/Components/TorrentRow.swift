import SwiftUI

struct TorrentRow: View {
    let torrent: TorrentInfo

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: torrent.statusBadge.iconName)
                    .font(.system(size: 24, weight: .regular))
                    .foregroundColor(.primary)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(torrent.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    Text(torrent.secondaryInfoLine)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.tertiaryLabel)
            }
            .padding(.vertical, 10)

            Divider()
                .padding(.leading, 56)
        }
        .background(Color.clear)
    }
}

#if DEBUG
#Preview {
    let now = Int64(Date().timeIntervalSince1970)

    let samples: [TorrentInfo] = [
        .demo(
            name: "Ubuntu 24.04.2 LTS (Noble Numbat) Desktop ISO x64",
            state: "downloading",
            progress: 0.68,
            dlspeed: 8_500_000,
            upspeed: 320_000,
            size: 5_876_543_210,
            ratio: 0.05,
            numSeeds: 142,
            numLeechs: 38,
            addedOn: now - 7200,
            completionOn: 0
        ),
        .demo(
            name: "Blender 4.3.0 macOS ARM64.dmg",
            state: "pausedDL",
            progress: 0.45,
            dlspeed: 0,
            upspeed: 0,
            size: 4_294_967_296,
            ratio: 0.11,
            numSeeds: 85,
            numLeechs: 12,
            addedOn: now - 86400,
            completionOn: 0
        ),
        .demo(
            name: "Debian 12.8.0 amd64 netinst.iso",
            state: "uploading",
            progress: 1.0,
            dlspeed: 0,
            upspeed: 6_200_000,
            size: 629_145_600,
            ratio: 3.42,
            numSeeds: 120,
            numLeechs: 0,
            addedOn: now - 604800,
            completionOn: now - 259200
        ),
        .demo(
            name: "Fedora-Workstation-Live-x86_64-41-1.4.iso",
            state: "stalledDL",
            progress: 0.92,
            dlspeed: 0,
            upspeed: 0,
            size: 2_147_483_648,
            ratio: 0.0,
            numSeeds: 45,
            numLeechs: 6,
            addedOn: now - 3600,
            completionOn: 0
        ),
        .demo(
            name: "macOS Sequoia 15.2 Installer.dmg",
            state: "error",
            progress: 0.08,
            dlspeed: 0,
            upspeed: 0,
            size: 14_680_064_000,
            ratio: 0.0,
            numSeeds: 0,
            numLeechs: 0,
            addedOn: now - 43200,
            completionOn: 0
        ),
    ]

    ZStack {
        LinearGradient(
            colors: [Color(hex: "#FFD1DC"), Color(hex: "#D8BFD8")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        ScrollView {
            VStack(spacing: 0) {
                ForEach(samples) { torrent in
                    TorrentRow(torrent: torrent)
                }
            }
            .padding(.horizontal, AppSpacing.lg)
        }
    }
}
#endif
