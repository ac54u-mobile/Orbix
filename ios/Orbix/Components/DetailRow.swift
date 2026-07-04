import SwiftUI

// MARK: - Detail Row

struct DetailRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    var valueColor: Color = AppColors.textSecondary

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .iconSymbol(iconColor)

            Text(label)
                .bodyFont()

            Spacer(minLength: 0)

            Text(value)
                .font(.system(size: 15, weight: .medium, design: .monospaced))
                .foregroundColor(valueColor)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, AppSpacing.sm)
        .padding(.horizontal, AppSpacing.lg)
        .frame(height: 44)
    }
}

#if DEBUG
#Preview {
    DetailRow(icon: "arrow.down", iconColor: AppColors.accentPrimary, label: "下载速度", value: "10.5 MB/s")
        .padding()
        .background(AppColors.gridBackgroundGradient)
}
#endif
