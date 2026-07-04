import SwiftUI

// MARK: - Action Tile

struct ActionTile: View {
    let icon: String
    let label: String
    let color: Color
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button {
            guard !isLoading else { return }
            AppHaptics.breathing()
            action()
        } label: {
            VStack(spacing: AppSpacing.xs) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.1))
                        .frame(width: IconLayout.sfSymbolSize, height: IconLayout.sfSymbolSize)

                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: color))
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(color)
                    }
                }

                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.sm)
            .background(Color.clear)
        }
        .buttonStyle(BreathingPressStyle())
        .accessibilityLabel(label)
        .disabled(isLoading)
    }
}

// MARK: - Breathing Press Style

private struct BreathingPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(AppMotion.breathingScale, value: configuration.isPressed)
    }
}

#if DEBUG
#Preview {
    ActionTile(icon: "play.fill", label: "启动", color: .green, isLoading: false, action: {})
        .padding()
        .background(AppColors.gridBackgroundGradient)
}
#endif
