import SwiftUI

// MARK: - Orbix Background — Frosted Glass + Native Materials

struct OrbixGridBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // Native gradient backdrop
            AppColors.gridBackgroundGradient

            // Frosted glass overlay
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            // Subtle grid lines (SF Symbol style)
            Canvas { context, size in
                let spacing: CGFloat = 120
                let path = Path { p in
                    var x: CGFloat = spacing
                    while x < size.width {
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x, y: size.height))
                        x += spacing
                    }
                    var y: CGFloat = spacing
                    while y < size.height {
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: size.width, y: y))
                        y += spacing
                    }
                }
                context.stroke(
                    path,
                    with: .color(Color.primary.opacity(0.015)),
                    style: StrokeStyle(lineWidth: 0.5, lineCap: .round)
                )
            }
            .drawingGroup()
        }
        .ignoresSafeArea()
    }
}

// MARK: - Pure Frosted Glass Background (No Grid)

struct GradientBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            AppColors.gridBackgroundGradient
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
        }
    }
}

// MARK: - View Modifier

struct OrbixBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    AppColors.gridBackgroundGradient(for: colorScheme)

                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()

                    Canvas { context, size in
                        let spacing: CGFloat = 120
                        let path = Path { p in
                            var x: CGFloat = spacing
                            while x < size.width {
                                p.move(to: CGPoint(x: x, y: 0))
                                p.addLine(to: CGPoint(x: x, y: size.height))
                                x += spacing
                            }
                            var y: CGFloat = spacing
                            while y < size.height {
                                p.move(to: CGPoint(x: 0, y: y))
                                p.addLine(to: CGPoint(x: size.width, y: y))
                                y += spacing
                            }
                        }
                        context.stroke(
                            path,
                            with: .color(Color.primary.opacity(0.015)),
                            style: StrokeStyle(lineWidth: 0.5, lineCap: .round)
                        )
                    }
                    .drawingGroup()
                }
                .ignoresSafeArea()
            )
    }
}

extension View {
    func orbixBackground() -> some View {
        modifier(OrbixBackgroundModifier())
    }
}