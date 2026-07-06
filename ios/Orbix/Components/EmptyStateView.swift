import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 44, weight: .light))
                .foregroundColor(AppColors.emptyStateIconColor)

            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)

            Text(subtitle)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(AppColors.emptyStateTextColor)
                .multilineTextAlignment(.center)

            if let actionTitle, let action {
                Button {
                    AppHaptics.light()
                    action()
                } label: {
                    Text(actionTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppColors.accentPrimary)
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.top, AppSpacing.sm)
            }
        }
        .padding(AppSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#if DEBUG
#Preview {
    EmptyStateView(
        icon: "tray",
        title: "No Items",
        subtitle: "There's nothing here yet.",
        actionTitle: "Add Something",
        action: {}
    )
}
#endif
