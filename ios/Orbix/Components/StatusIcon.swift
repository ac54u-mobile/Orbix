import SwiftUI

struct StatusIcon: View {
    let status: TorrentStatus

    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)
                .frame(width: 28, height: 28)

            Image(systemName: iconName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(iconColor)
        }
    }

    private var iconName: String {
        switch status {
        case .downloading, .stalledDL, .forcedDL: return "arrow.down"
        case .uploading, .stalledUP, .forcedUP: return "arrow.up"
        case .pausedDL, .pausedUP, .stoppedDL, .stoppedUP: return "pause.fill"
        case .queuedDL, .queuedUP: return "clock.fill"
        case .error, .missingFiles: return "exclamationmark.triangle.fill"
        case .checkingDL, .checkingUP, .checkingResumeData, .allocating: return "arrow.triangle.2.circlepath"
        case .metaDL: return "doc.text.magnifyingglass"
        case .moving: return "folder.fill"
        default: return "questionmark"
        }
    }

    private var backgroundColor: Color {
        switch status {
        case .uploading, .stalledUP, .forcedUP: return AppColors.success.opacity(0.15)
        case .downloading, .metaDL, .forcedDL, .stalledDL: return AppColors.accent.opacity(0.15)
        case .error, .missingFiles: return AppColors.danger.opacity(0.15)
        case .pausedDL, .pausedUP, .stoppedDL, .stoppedUP, .queuedDL, .queuedUP, .moving: return AppColors.tertiaryLabel.opacity(0.15)
        default: return AppColors.separator.opacity(0.3)
        }
    }
    
    private var iconColor: Color {
        switch status {
        case .uploading, .stalledUP, .forcedUP: return AppColors.success
        case .downloading, .metaDL, .forcedDL, .stalledDL: return AppColors.accent
        case .error, .missingFiles: return AppColors.danger
        case .pausedDL, .pausedUP, .stoppedDL, .stoppedUP, .queuedDL, .queuedUP, .moving: return AppColors.secondaryLabel
        default: return AppColors.secondaryLabel
        }
    }
}
