import SwiftUI

struct StarryBackground: View {
    @State private var points: [StarPoint] = []

    var body: some View {
        ZStack {
            AppColors.backgroundGradient

            Canvas { context, size in
                for point in points {
                    let rect = CGRect(x: point.x * size.width,
                                      y: point.y * size.height,
                                      width: point.radius,
                                      height: point.radius)
                    let path = Path(ellipseIn: rect)
                    context.fill(path, with: .color(.white.opacity(point.opacity)))
                }
            }
            .drawingGroup()
        }
        .ignoresSafeArea()
        .onAppear {
            if points.isEmpty {
                points = generateStars(count: 120)
            }
        }
    }
}

private struct StarPoint {
    let x: CGFloat
    let y: CGFloat
    let radius: CGFloat
    let opacity: Double
}

private func generateStars(count: Int) -> [StarPoint] {
    var rng = SeededRandom(seed: 42)
    return (0..<count).map { _ in
        StarPoint(
            x: CGFloat(rng.next()),
            y: CGFloat(rng.next()),
            radius: CGFloat(rng.range(0.5...2.0)),
            opacity: Double.random(in: 0.15...0.55)
        )
    }
}

private struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        let t = UInt64((state &* (state ^ (state >> 33))) &+ 2_525_870_597_928_498_105)
        return Double(t % 1_000_000) / 1_000_000.0
    }

    mutating func range(_ range: ClosedRange<Double>) -> Double {
        range.lowerBound + next() * (range.upperBound - range.lowerBound)
    }
}

// MARK: - View Modifier

struct StarryBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    AppColors.backgroundGradient

                    Canvas { context, size in
                        let seed: [StarPoint] = generateStars(count: 120)
                        for point in seed {
                            let rect = CGRect(
                                x: point.x * size.width,
                                y: point.y * size.height,
                                width: point.radius,
                                height: point.radius
                            )
                            context.fill(Path(ellipseIn: rect),
                                         with: .color(.white.opacity(point.opacity)))
                        }
                    }
                    .drawingGroup()
                }
                .ignoresSafeArea()
            )
    }
}

extension View {
    func starryBackground() -> some View {
        modifier(StarryBackgroundModifier())
    }
}

// MARK: - Pure Gradient Background (no stars)

struct GradientBackground: View {
    var body: some View {
        AppColors.backgroundGradient.ignoresSafeArea()
    }
}
