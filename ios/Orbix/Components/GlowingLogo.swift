import SwiftUI

struct GlowingLogo: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.blue.gradient)
                .frame(width: size, height: size)
                .shadow(color: Color.blue.opacity(0.4), radius: size * 0.25, x: 0, y: 4)

            Image(systemName: "icloud.and.arrow.down.fill")
                .font(.system(size: size * 0.35, weight: .medium))
                .foregroundColor(.white)
        }
    }
}

#if DEBUG
#Preview {
    GlowingLogo(size: 80)
}
#endif
