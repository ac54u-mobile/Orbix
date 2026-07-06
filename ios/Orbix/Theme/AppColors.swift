import SwiftUI

// MARK: - Semantic Color Tokens — iOS Native Design

enum AppColors {
    // Background — System-native
    static let backgroundBase          = Color(.systemBackground)
    static let backgroundGradientStart = Color(.systemBackground)
    static let backgroundGradientEnd   = Color(.systemGroupedBackground)
    static let gridGradientStart       = Color(.systemBackground)
    static let gridGradientEnd         = Color(.systemGroupedBackground)

    // Background — Dark Mode
    static let backgroundGradientStartDark = Color(.systemBackground)
    static let backgroundGradientEndDark   = Color(.systemGroupedBackground)
    static let gridGradientStartDark       = Color(.systemBackground)
    static let gridGradientEndDark         = Color(.systemGroupedBackground)

    // Surface — frosted glass via system materials
    static let card                     = Color(.systemBackground)
    static let elevated                 = Color(.secondarySystemGroupedBackground)
    // Dark mode optimized
    static let cardDark                 = Color(.systemBackground)
    static let elevatedDark             = Color(.secondarySystemGroupedBackground)

    // Text
    static let textPrimary              = Color(.label)
    static let textSecondary            = Color(.secondaryLabel)
    static let textTertiary             = Color(.tertiaryLabel)

    // Accent
    static let accentPrimary            = Color.blue
    static let accentDark               = Color.blue.opacity(0.8)
    static let accentSoftBg             = Color.blue.opacity(0.1)

    // Tag Backgrounds
    static let tagBackgroundGreen       = Color.green
    static let tagBackgroundBlue        = Color.blue

    // Semantic
    static let success                  = Color.green
    static let warning                  = Color.orange
    static let danger                   = Color.red

    // Chart / Waveform
    static let statsWaveform            = Color.green

    // Separator / Divider
    static let listDivider              = Color(.separator)
    static let separator                = listDivider
    static let hairlineDivider          = Color(.separator).opacity(0.5)
    static let placeholder              = Color(.placeholderText)

    // Skeleton
    static let skeletonBase             = Color(.systemGray5)
    static let skeletonHighlight        = Color(.systemGray4)

    // Glass / Translucent
    static let glassBorder              = Color(.separator).opacity(0.3)

    // Empty State
    static let emptyStateIconColor      = Color(.tertiaryLabel)
    static let emptyStateTextColor      = Color(.secondaryLabel)

    // Gradients — Light mode defaults (backward-compatible)
    static let backgroundGradient = LinearGradient(
        colors: [Color(.systemBackground), Color(.systemGroupedBackground)],
        startPoint: .top,
        endPoint: .bottom
    )

    static let gridBackgroundGradient = LinearGradient(
        colors: [Color(.systemBackground), Color(.systemGroupedBackground)],
        startPoint: .top,
        endPoint: .bottom
    )

    // Gradients — ColorScheme-aware variants
    static func backgroundGradient(for colorScheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: [Color(.systemBackground), Color(.systemGroupedBackground)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static func gridBackgroundGradient(for colorScheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: [Color(.systemBackground), Color(.systemGroupedBackground)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static let logoGradient = LinearGradient(
        colors: [Color.blue, Color.blue.opacity(0.7)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - System Color Helpers

extension Color {
    static let systemBackgroundGrouped = Color(.systemGroupedBackground)
    static let systemBackgroundSecondaryGrouped = Color(.secondarySystemGroupedBackground)
    static let systemFillTertiary = Color(.tertiarySystemFill)
}

// MARK: - 8pt Grid Layout Constants

enum AppRadius {
    static let xs: CGFloat  = 4
    static let sm: CGFloat  = 8
    static let md: CGFloat  = 12
    static let lg: CGFloat  = 16
    static let xl: CGFloat  = 24
    static let xxl: CGFloat = 32
}

enum AppSpacing {
    static let xs: CGFloat  = 4
    static let sm: CGFloat  = 8
    static let md: CGFloat  = 12
    static let lg: CGFloat  = 16
    static let xl: CGFloat  = 24
    static let xxl: CGFloat = 32
}

// MARK: - Page Layout Configs

enum SettingsConfig {
    static let containerCornerRadius: CGFloat = AppRadius.lg
    static let listRowHeight: CGFloat         = 72.0
    static let overallSpacing: CGFloat        = AppSpacing.lg
    static let itemContentSpacing: CGFloat    = AppSpacing.md
    static let iconSize: CGSize               = CGSize(width: 24, height: 24)
}

enum StatsViewConfig {
    static let containerCornerRadius: CGFloat   = AppRadius.lg
    static let listRowHeight: CGFloat           = 72.0
    static let elementSpacing: CGFloat          = AppSpacing.lg
    static let waveformWidthMultiplier: CGFloat = 0.8
}

// MARK: - Icon Layout

enum IconLayout {
    static let sfSymbolSize: CGFloat = 28

    struct SFSymbolFrameModifier: ViewModifier {
        func body(content: Content) -> some View {
            content
                .font(.system(size: 14, weight: .semibold))
                .frame(width: IconLayout.sfSymbolSize, height: IconLayout.sfSymbolSize)
        }
    }
}

extension View {
    func sfSymbolFrame() -> some View {
        modifier(IconLayout.SFSymbolFrameModifier())
    }
}

// MARK: - Orbix Card Modifier — Frosted Glass

struct OrbixCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                    .stroke(AppColors.glassBorder, lineWidth: 1)
            )
    }
}

extension View {
    func orbixCard() -> some View {
        modifier(OrbixCard())
    }
}