import SwiftUI

// MARK: - Torrent Row (native list row)

struct TorrentRow: View {
    let torrent: TorrentInfo
    @ObservedObject private var subtitleBadges = SubtitleBadgeStore.shared

    private var hasSubtitle: Bool { subtitleBadges.hashes.contains(torrent.hash) }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            StatusIcon(status: torrent.statusBadge)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 5) {
                Text(torrent.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)

                metadataLine

                if torrent.addedOn > 0 || (torrent.isCompleted && torrent.completionOn > 0) || hasSubtitle {
                    timeLine
                }

                if torrent.statusBadge.isError && !torrent.errorString.isEmpty {
                    Text(torrent.errorString)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(1)
                }

                if !torrent.isCompleted && torrent.progress > 0 {
                    HStack(spacing: 8) {
                        ProgressView(value: torrent.progress)
                            .tint(torrent.lineStatusColor)

                        Text("\(torrent.progressPercent)%")
                            .font(.caption2.weight(.medium))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityHidden(true)
                }
            }

            Spacer(minLength: 0)

            trailingBadge
                .padding(.top, 6)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(torrent.name)
        .accessibilityValue(torrent.secondaryInfoLine)
        .accessibilityHint(String(localized: "Double-tap to view details"))
    }

    private var metadataLine: some View {
        HStack(spacing: 10) {
            Text(torrent.statusBadge.displayName)

            Text(formatBytes(torrent.size))

            if torrent.dlspeed > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 9, weight: .bold))
                    Text(formatSpeed(torrent.dlspeed))
                        .monospacedDigit()
                }
                .foregroundStyle(.blue)
            }

            if torrent.upspeed > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 9, weight: .bold))
                    Text(formatSpeed(torrent.upspeed))
                        .monospacedDigit()
                }
                .foregroundStyle(.green)
            }

            if torrent.dlspeed > 0 && torrent.eta > 0 && !torrent.isCompleted {
                HStack(spacing: 2) {
                    Image(systemName: "clock")
                        .font(.system(size: 9, weight: .medium))
                    Text(torrent.etaFormatted)
                        .monospacedDigit()
                }
            }

            if !torrent.isCompleted && torrent.dlspeed > 0 && (torrent.numSeeds > 0 || torrent.numLeechs > 0) {
                HStack(spacing: 2) {
                    Image(systemName: "person.2")
                        .font(.system(size: 9, weight: .medium))
                    Text("\(torrent.numSeeds)/\(torrent.numLeechs)")
                        .monospacedDigit()
                }
            }

            if torrent.isCompleted && torrent.ratio > 0 {
                Text(String(format: String(localized: "比例 %.2f", comment: "Ratio"), torrent.ratio))
                    .monospacedDigit()
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }

    private var timeLine: some View {
        HStack(spacing: 10) {
            if torrent.addedOn > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 9, weight: .medium))
                    Text(String(format: String(localized: "添加于 %@", comment: "Added at"), relativeTime(from: torrent.addedOn)))
                }
            }

            if torrent.isCompleted && torrent.completionOn > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 9, weight: .medium))
                    Text(String(format: String(localized: "完成于 %@", comment: "Completed at"), relativeTime(from: torrent.completionOn)))
                }
            }

            if hasSubtitle {
                HStack(spacing: 3) {
                    Image(systemName: "captions.bubble.fill")
                        .font(.system(size: 9, weight: .medium))
                    Text(String(localized: "已翻译字幕", comment: "Subtitle translated"))
                }
                .foregroundStyle(.purple)
            }
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
        .lineLimit(1)
    }

    @ViewBuilder
    private var trailingBadge: some View {
        if torrent.isCompleted {
            Image(systemName: "checkmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(.green)
                .accessibilityLabel(OrbixStrings.filterCompleted)
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
