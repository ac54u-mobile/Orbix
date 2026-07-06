import SwiftUI

// MARK: - Global Speed Pill (system material)

struct GlobalSpeedPill: View {
    let dl: Int64
    let up: Int64

    var body: some View {
        HStack(spacing: 16) {
            if dl > 0 {
                Label(formatSpeed(dl), systemImage: "arrow.down")
                    .font(.footnote.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.blue)
            }

            if up > 0 {
                Label(formatSpeed(up), systemImage: "arrow.up")
                    .font(.footnote.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.green)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
    }
}

#if DEBUG
#Preview {
    GlobalSpeedPill(dl: 10240000, up: 5120000)
}
#endif
