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
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                action()
            }
        }) {
            VStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: color))
                        .frame(height: 20)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(color)
                        .frame(height: 20)
                }

                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.label)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppColors.card)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isLoading)
    }
}
