import SwiftUI

// MARK: - Global Speed Pill

struct GlobalSpeedPill: View {
    let dl: Int64
    let up: Int64

    var body: some View {
        HStack(spacing: AppSpacing.lg) {
            if dl > 0 {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "arrow.down")
                        .iconSymbol(AppColors.accentPrimary)
                    Text(formatSpeed(dl))
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(AppColors.accentPrimary)
                }
            }

            if up > 0 {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "arrow.up")
                        .iconSymbol(AppColors.success)
                    Text(formatSpeed(up))
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(AppColors.success)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, AppSpacing.md)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(AppColors.glassBorder, lineWidth: 0.5)
                )
        )
    }
}

#if DEBUG
#Preview {
    GlobalSpeedPill(dl: 10240000, up: 5120000)
}
#endif
