import SwiftUI

// MARK: - Torrent Row (native list row)

struct TorrentRow: View {
    let torrent: TorrentInfo

    var body: some View {
        HStack(spacing: 12) {
            StatusIcon(status: torrent.statusBadge)

            VStack(alignment: .leading, spacing: 4) {
                Text(torrent.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)

                Text(torrent.secondaryInfoLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                if !torrent.isCompleted && torrent.progress > 0 {
                    ProgressView(value: torrent.progress)
                        .tint(torrent.lineStatusColor)
                        .accessibilityHidden(true)
                }
            }

            Spacer(minLength: 0)

            trailingBadge
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(torrent.name)
        .accessibilityValue(torrent.secondaryInfoLine)
        .accessibilityHint(String(localized: "Double-tap to view details"))
    }

    @ViewBuilder
    private var trailingBadge: some View {
        if torrent.isCompleted {
            Text(OrbixStrings.filterCompleted)
                .font(.caption.weight(.medium))
                .foregroundStyle(.green)
        } else {
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
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
    List(samples) { t in
        TorrentRow(torrent: t)
    }
    .listStyle(.plain)
}
#endif
