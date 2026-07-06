import SwiftUI

// MARK: - Orbix Grid Background

struct OrbixGridBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var cachedGrid: [GridLine] = []
    private let gridSpacing: CGFloat = 120

    var body: some View {
        ZStack {
            AppColors.gridBackgroundGradient(for: colorScheme)

            Canvas { context, size in
                let lines = cachedGrid.isEmpty ? generateGridLines(size: size) : cachedGrid

                let path = Path { p in
                    for line in lines {
                        p.move(to: line.start)
                        p.addLine(to: line.end)
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
        .onAppear {
            if cachedGrid.isEmpty {
                cachedGrid = generateGridLines(
                    size: CGSize(
                        width: UIScreen.main.bounds.width,
                        height: UIScreen.main.bounds.height
                    )
                )
            }
        }
    }

    private func generateGridLines(size: CGSize) -> [GridLine] {
        var lines: [GridLine] = []

        var x: CGFloat = gridSpacing
        while x < size.width {
            lines.append(GridLine(
                start: CGPoint(x: x, y: 0),
                end: CGPoint(x: x, y: size.height)
            ))
            x += gridSpacing
        }

        var y: CGFloat = gridSpacing
        while y < size.height {
            lines.append(GridLine(
                start: CGPoint(x: 0, y: y),
                end: CGPoint(x: size.width, y: y)
            ))
            y += gridSpacing
        }

        return lines
    }
}

private struct GridLine {
    let start: CGPoint
    let end: CGPoint
}

// MARK: - Pure Gradient Background (Fallback)

struct GradientBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        AppColors.gridBackgroundGradient(for: colorScheme).ignoresSafeArea()
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

                    Canvas { context, size in
                        let spacing: CGFloat = 120
                        var x: CGFloat = spacing
                        var y: CGFloat = spacing
                        let path = Path { p in
                            while x < size.width {
                                p.move(to: CGPoint(x: x, y: 0))
                                p.addLine(to: CGPoint(x: x, y: size.height))
                                x += spacing
                            }
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
