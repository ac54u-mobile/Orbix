import SwiftUI

struct WelcomeView: View {
    let onAddServer: () -> Void

    var body: some View {
        ZStack {
            AppColors.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                GlowingLogo(size: 88)

                Text("Orbix")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)

                Text(OrbixStrings.welcomeQBittorrent)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)

                VStack(spacing: 12) {
                    FeatureTile(
                        icon: "plus.app.fill",
                        title: OrbixStrings.navAddServer,
                        subtitle: OrbixStrings.welcomeSubtitle1
                    )
                    FeatureTile(
                        icon: "link",
                        title: OrbixStrings.welcomeAddServer,
                        subtitle: OrbixStrings.welcomeSubtitle2
                    )
                    FeatureTile(
                        icon: "arrow.down.doc.fill",
                        title: OrbixStrings.welcomeManageTorrents,
                        subtitle: OrbixStrings.welcomeSubtitle3
                    )
                }
                .padding(.horizontal, 20)

                Spacer()

                Button {
                    AppHaptics.medium()
                    onAddServer()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                        Text(OrbixStrings.btnStartSetup)
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                            .fill(AppColors.accentPrimary)
                            .shadow(color: AppColors.accentPrimary.opacity(0.3), radius: 12, x: 0, y: 6)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }
}

#if DEBUG
#Preview {
    WelcomeView(onAddServer: {})
}
#endif

private struct FeatureTile: View {
    let icon: String
    let title: String
    let subtitle: String

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppColors.accentPrimary.opacity(0.15))
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppColors.accentPrimary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)

                Text(subtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                        .stroke(AppColors.glassBorder, lineWidth: 0.5)
                )
        )
    }
}

