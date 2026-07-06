import SwiftUI

// MARK: - Shimmer Skeleton Bar

struct SkeletonBar: View {
    var height: CGFloat = 12
    var width: CGFloat? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shimmerOffset: CGFloat = -200

    var body: some View {
        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
            .fill(AppColors.skeletonBase)
            .overlay {
                if !reduceMotion {
                    RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.clear, Color.primary.opacity(0.3), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .offset(x: shimmerOffset)
                        .mask {
                            RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                        }
                }
            }
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil)
            .clipped()
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(
                    .linear(duration: AppMotion.shimmerDuration)
                    .repeatForever(autoreverses: false)
                ) {
                    shimmerOffset = 200
                }
            }
            .onDisappear { shimmerOffset = -200 }
    }
}

// MARK: - Skeleton List

struct SkeletonList: View {
    let count: Int

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0 ..< count, id: \.self) { _ in
                skeletonRow
            }
        }
    }

    private var skeletonRow: some View {
        HStack(spacing: AppSpacing.md) {
            SkeletonBar(height: 28, width: 28)
                .cornerRadius(AppRadius.sm)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                SkeletonBar(height: 17, width: 160)
                SkeletonBar(height: 13, width: 100)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.lg)
        .frame(height: 56)
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 20) {
        SkeletonBar(height: 12)
        SkeletonBar(height: 17, width: 200)
        SkeletonList(count: 5)
    }
    .padding()
    .background(AppColors.gridBackgroundGradient)
}
#endif
