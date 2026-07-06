import SwiftUI

// MARK: - iOS 26 Liquid Glass Design System
//
// Usage:
//   .liquidGlass(.regular)       — standard card
//   .liquidGlass(.thick)         — elevated sheet
//   .liquidGlass(.chrome)        — navigation bar
//   LiquidGlassCard { content }  — convenience wrapper

// MARK: - Glass Thickness Level

enum LiquidGlassLevel {
    case thin       // near-transparent overlay
    case regular    // standard card
    case thick      // elevated surface
    case chrome     // highest elevation

    var cornerRadius: CGFloat {
        switch self {
        case .thin:    return AppRadius.sm
        case .regular: return AppRadius.lg
        case .thick:   return AppRadius.xl
        case .chrome:  return AppRadius.xxl
        }
    }

    func backgroundColor(for scheme: ColorScheme) -> Color {
        switch self {
        case .thin:    return AppColors.glassThin(for: scheme)
        case .regular: return AppColors.glassRegular(for: scheme)
        case .thick:   return AppColors.glassThick(for: scheme)
        case .chrome:  return AppColors.glassChrome(for: scheme)
        }
    }
}

// MARK: - Liquid Glass ViewModifier

struct LiquidGlassModifier: ViewModifier {
    let level: LiquidGlassLevel

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: level.cornerRadius, style: .continuous)
                    .fill(level.backgroundColor(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: level.cornerRadius, style: .continuous)
                    .stroke(AppColors.glassBorder(for: colorScheme), lineWidth: 0.5)
            )
    }
}

// MARK: - Liquid Glass Card (convenience wrapper)

struct LiquidGlassCard<Content: View>: View {
    let level: LiquidGlassLevel
    @ViewBuilder let content: () -> Content

    init(level: LiquidGlassLevel = .regular, @ViewBuilder content: @escaping () -> Content) {
        self.level = level
        self.content = content
    }

    var body: some View {
        content()
            .padding(AppSpacing.lg)
            .modifier(LiquidGlassModifier(level: level))
    }
}

// MARK: - View Extensions

extension View {
    /// Apply iOS 26 Liquid Glass surface to any view
    func liquidGlass(_ level: LiquidGlassLevel = .regular) -> some View {
        modifier(LiquidGlassModifier(level: level))
    }

    /// Apply Liquid Glass with custom corner radius
    func liquidGlass(_ level: LiquidGlassLevel = .regular, cornerRadius: CGFloat) -> some View {
        modifier(LiquidGlassCustomRadiusModifier(level: level, cornerRadius: cornerRadius))
    }
}

// MARK: - Custom Corner Radius Variant

private struct LiquidGlassCustomRadiusModifier: ViewModifier {
    let level: LiquidGlassLevel
    let cornerRadius: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(level.backgroundColor(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppColors.glassBorder(for: colorScheme), lineWidth: 0.5)
            )
    }
}

// MARK: - Preview

#if DEBUG
private struct LiquidGlassPreview: View {
    var body: some View {
        ZStack {
            AppColors.gridBackgroundGradient(for: .dark).ignoresSafeArea()

            VStack(spacing: AppSpacing.lg) {
                LiquidGlassCard(level: .thin) {
                    Text("Thin Glass")
                        .font(AppTypography.titleSmall())
                }

                LiquidGlassCard(level: .regular) {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("Regular Glass Card")
                            .font(AppTypography.titleSmall())
                        Text("Standard surface for list rows and content cards.")
                            .font(AppTypography.descriptionSmall())
                    }
                }

                LiquidGlassCard(level: .thick) {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("Thick Glass Sheet")
                            .font(AppTypography.titleSmall())
                        Text("Elevated surface for sheets and dialogs.")
                            .font(AppTypography.descriptionSmall())
                    }
                }

                LiquidGlassCard(level: .chrome) {
                    Text("Chrome Glass — Navigation")
                        .font(AppTypography.titleSmall())
                }
            }
            .padding()
        }
    }
}

#Preview("Dark Mode") {
    LiquidGlassPreview()
        .preferredColorScheme(.dark)
}

#Preview("Light Mode") {
    LiquidGlassPreview()
        .preferredColorScheme(.light)
}
#endif
