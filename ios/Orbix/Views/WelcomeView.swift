import SwiftUI

struct WelcomeView: View {
    let onAddServer: () -> Void

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                GlowingLogo(size: 88)

                Text("Orbix")
                    .font(.system(.title, design: .rounded).bold())

                Text(OrbixStrings.welcomeQBittorrent)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

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
                    Label(OrbixStrings.btnStartSetup, systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
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

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

