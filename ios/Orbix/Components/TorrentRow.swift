import SwiftUI

struct TorrentRow: View {
    let torrent: TorrentInfo

    var body: some View {
        HStack(spacing: 16) {
            statusIconView

            VStack(alignment: .leading, spacing: 4) {
                Text(torrent.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color(.label))
                    .lineLimit(2)

                Text(torrent.secondaryInfoLine)
                    .font(.system(size: 13))
                    .foregroundColor(Color(.secondaryLabel))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(.tertiaryLabel))
        }
        .padding(.vertical, 12)
    }

    private var statusColor: Color {
        switch torrent.statusBadge {
        case .downloading, .forcedDL, .metaDL, .allocating:
            return AppColors.accent
        case .uploading, .forcedUP:
            return AppColors.success
        case .stalledDL, .stalledUP:
            return AppColors.warning
        case .checkingDL, .checkingUP, .checkingResumeData, .moving:
            return Color.purple
        case .pausedDL, .pausedUP, .stoppedDL, .stoppedUP, .queuedDL, .queuedUP:
            return AppColors.placeholder
        case .error, .missingFiles:
            return AppColors.danger
        default:
            return AppColors.placeholder
        }
    }

    private var statusIconView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(statusColor)
            Image(systemName: torrent.statusBadge.iconName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
        }
        .frame(width: 36, height: 36)
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
            ForEach(Array(samples.enumerated()), id: \.element.id) { idx, t in
                TorrentRow(torrent: t)
                    .padding(.horizontal, 16)
                    .background(Color(.secondarySystemGroupedBackground))
                if idx < samples.count - 1 { Divider().padding(.leading, 68) }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
        .padding(.top, 20)
    }
    .background(Color(.systemGroupedBackground))
}
#endif
