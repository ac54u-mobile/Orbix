import SwiftUI

struct ProgressBar: View {
    let progress: Double
    var height: CGFloat = 0.5  // hairline: 1 pixel (0.5 pt on 2x display)
    var color: Color = AppColors.accent

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(AppColors.separator)
                    .frame(height: height)

                Rectangle()
                    .fill(color)
                    .frame(width: geo.size.width * CGFloat(min(max(progress, 0), 1)), height: height)
                    .animation(.linear(duration: 0.3), value: progress)
            }
        }
        .frame(height: height)
    }
}

#if DEBUG
#Preview {
    ProgressBar(progress: 0.65)
}
#endif

struct SpeedBadge: View {
    let speed: Int64

    var body: some View {
        Text(formatSpeed(speed))
            .caption(AppColors.tertiaryLabel)
    }
}

struct SizeText: View {
    let bytes: Int64

    var body: some View {
        Text(formatBytes(bytes))
            .subtitle()
    }
}
