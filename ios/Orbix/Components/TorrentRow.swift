import SwiftUI

struct TorrentRow: View {
    let torrent: TorrentInfo

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            StatusIcon(status: torrent.statusBadge)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Text(torrent.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.label)
                        .lineLimit(2)
                        .padding(.trailing, 8)
                    
                    Spacer(minLength: 0)
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatBytes(torrent.size))
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(AppColors.secondaryLabel)
                        if torrent.ratio > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 10, weight: .medium))
                                Text(String(format: "%.2f", torrent.ratio))
                                    .font(.system(size: 13, design: .monospaced))
                            }
                            .foregroundColor(torrent.ratio >= 1.0 ? AppColors.success : AppColors.warning)
                        }
                    }
                }
                
                HStack(spacing: 6) {
                    statusBadge
                    
                    Text("\u{2022}")
                        .foregroundColor(AppColors.tertiaryLabel)
                        .font(.system(size: 10))
                    
                    Text("\(torrent.progressPercent)%")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(AppColors.secondaryLabel)
                    
                    if torrent.dlspeed > 0 {
                        Text("\u{2022}")
                            .foregroundColor(AppColors.tertiaryLabel)
                            .font(.system(size: 10))
                        Text("↓\(formatSpeed(torrent.dlspeed))")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(AppColors.accent)
                    }
                    
                    if torrent.upspeed > 0 {
                        Text("\u{2022}")
                            .foregroundColor(AppColors.tertiaryLabel)
                            .font(.system(size: 10))
                        Text("↑\(formatSpeed(torrent.upspeed))")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(AppColors.success)
                    }
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 1, style: .continuous)
                            .fill(AppColors.separator.opacity(0.5))
                        
                        RoundedRectangle(cornerRadius: 1, style: .continuous)
                            .fill(torrent.progressColor)
                            .frame(width: max(0, geometry.size.width * CGFloat(torrent.progress)))
                    }
                }
                .frame(height: 2.5)
                .padding(.top, 2)
            }
        }
    }

    private var statusBadge: some View {
        Text(torrent.statusBadge.displayName)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(torrent.statusBadge.statusColor)
    }


#if DEBUG
#Preview {
    TorrentRow(torrent: .demo())
        .padding()
}
#endif
