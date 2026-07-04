import SwiftUI

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    var icon: String? = nil
    var showDivider: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppSpacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .iconSymbol(AppColors.textTertiary)
                }

                Text(title)
                    .descriptionSmall(AppColors.textSecondary)
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
            }
            .padding(.leading, AppSpacing.lg)
            .padding(.bottom, AppSpacing.xs)
            .frame(maxWidth: .infinity, alignment: .leading)

            if showDivider {
                Rectangle()
                    .fill(AppColors.hairlineDivider)
                    .frame(height: 0.5)
            }
        }
    }
}

#if DEBUG
#Preview {
    SectionHeader(title: "示例标题", icon: "arrow.down", showDivider: true)
}
#endif
