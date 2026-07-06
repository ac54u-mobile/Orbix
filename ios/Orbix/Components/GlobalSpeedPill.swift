import SwiftUI

// MARK: - Global Speed Pill (iOS 26 Liquid Glass)

struct GlobalSpeedPill: View {
    let dl: Int64
    let up: Int64

    @Environment(\.colorScheme) private var colorScheme

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
                .fill(AppColors.glassThick(for: colorScheme))
        )
        .overlay(
            Capsule()
                .stroke(AppColors.glassBorder(for: colorScheme), lineWidth: 0.5)
        )
    }
}

#if DEBUG
#Preview {
    GlobalSpeedPill(dl: 10240000, up: 5120000)
}
#endif
