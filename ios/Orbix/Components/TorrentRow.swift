import SwiftUI

struct TorrentRow: View {
    let torrent: TorrentInfo

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                statusIconView

                VStack(alignment: .leading, spacing: 3) {
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

                trailingBadge
            }
            .padding(.vertical, 12)

            Divider()
        }
        .background(Color.clear)
    }

    private var statusIconView: some View {
        Image(systemName: torrent.statusBadge.iconName)
            .font(.system(size: 20, weight: .light))
            .foregroundColor(.primary)
            .frame(width: 28, height: 28)
    }

    @ViewBuilder
    private var trailingBadge: some View {
        if torrent.isCompleted {
            Text("已完成")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppColors.success)
        } else {
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(.tertiaryLabel))
        }
    }
}

#if DEBUG
#Preview {
    let now = Int64(Date().timeIntervalSince1970)
    let samples: [TorrentInfo] = [
        .demo(name: "Ubuntu 24.04.2 LTS Desktop ISO x64", state: "downloading", progress: 0.68, dlspeed: 8_500_000, upspeed: 0, size: 5_876_543_210, ratio: 0.05, numSeeds: 142, numLeechs: 38, addedOn: now - 7200, completionOn: 0),
        .demo(name: "Blender 4.3.0 macOS ARM64.dmg", state: "pausedDL", progress: 0.45, dlspeed: 0, upspeed: 0, size: 4_294_967_296, ratio: 0.11, numSeeds: 85, numLeechs: 12, addedOn: now - 86400, completionOn: 0),
        .demo(name: "Debian 12.8.0 amd64 netinst.iso", state: "uploading", progress: 1.0, dlspeed: 0, upspeed: 6_200_000, size: 629_145_600, ratio: 3.42, numSeeds: 120, numLeechs: 0, addedOn: now - 604800, completionOn: now - 259200),
        .demo(name: "Fedora-Workstation-Live-x86_64-41-1.4.iso", state: "error", progress: 0.08, dlspeed: 0, upspeed: 0, size: 2_147_483_648, ratio: 0.0, numSeeds: 0, numLeechs: 0, addedOn: now - 43200, completionOn: 0),
    ]
    ScrollView {
        VStack(spacing: 0) {
            ForEach(samples) { t in
                TorrentRow(torrent: t)
                    .padding(.horizontal, 16)
                    .background(Color.clear)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
    }
    .background(
        LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.94, blue: 0.97),
                Color(red: 0.90, green: 0.95, blue: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    )
    .preferredColorScheme(.light)
}
#endif
