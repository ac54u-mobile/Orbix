import SwiftUI

struct ActionTile: View {
    let icon: String
    let label: String
    let color: Color
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            if !isLoading {
                AppHaptics.medium()
                action()
            }
        }) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(color.opacity(0.12))
                        .frame(width: 44, height: 44)
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: color))
                            .frame(width: 22, height: 22)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(color)
                    }
                }

                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                    .fill(Color(.systemBackground).opacity(0.85))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                            .stroke(Color(.separator).opacity(0.5), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(label)
        .disabled(isLoading)
    }
}

#if DEBUG
#Preview {
    ActionTile(icon: "play.fill", label: "启动", color: .green, isLoading: false, action: {})
}
#endif
