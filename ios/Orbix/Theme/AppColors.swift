import SwiftUI

// MARK: - Semantic Color Tokens

enum AppColors {
    // Background — Light Mode
    static let backgroundBase          = Color(red: 0.98, green: 0.96, blue: 0.98)
    static let backgroundGradientStart = Color(red: 0.996, green: 0.949, blue: 0.965)
    static let backgroundGradientEnd   = Color(red: 0.941, green: 0.957, blue: 1.0)
    static let gridGradientStart       = Color(hex: "#FEF2F6")
    static let gridGradientEnd         = Color(hex: "#F0F4FE")

    // Background — Dark Mode
    static let backgroundGradientStartDark = Color(hex: "#1A1A2E")
    static let backgroundGradientEndDark   = Color(hex: "#16213E")
    static let gridGradientStartDark       = Color(hex: "#1C1C30")
    static let gridGradientEndDark         = Color(hex: "#1A2236")

    // Surface — adapts automatically via .systemBackground
    // Lighter glass effect in light mode, more opaque in dark mode
    static let card                     = Color(.systemBackground).opacity(0.6)
    static let elevated                 = Color(.systemBackground).opacity(0.72)
    // Dark mode optimized: use .cardDark / .elevatedDark for better contrast
    static let cardDark                 = Color(.systemBackground).opacity(0.85)
    static let elevatedDark             = Color(.systemBackground).opacity(0.9)

    // Text
    static let textPrimary              = Color(.label)
    static let textSecondary            = Color(.secondaryLabel)
    static let textTertiary             = Color(.tertiaryLabel)

    // Accent
    static let accentPrimary            = Color(hex: "#007AFF")
    static let accentDark               = Color(hex: "#0056D6")
    static let accentSoftBg             = Color(hex: "#E8F1FF")

    // Tag Backgrounds
    static let tagBackgroundGreen       = Color(hex: "#34C759")
    static let tagBackgroundBlue        = Color(hex: "#409CFF")

    // Semantic
    static let success                  = Color(hex: "#34C759")
    static let warning                  = Color(hex: "#FF9500")
    static let danger                   = Color(hex: "#FF3B30")

    // Chart / Waveform
    static let statsWaveform            = Color(hex: "#34C759")

    // Separator / Divider
    static let listDivider              = Color(.separator)
    static let separator                = listDivider
    static let hairlineDivider          = Color.primary.opacity(0.08)
    static let placeholder              = Color(.placeholderText)

    // Skeleton
    static let skeletonBase             = Color(.systemGray5)
    static let skeletonHighlight        = Color(.systemGray6)

    // Glass / Translucent
    static let glassBorder              = Color.primary.opacity(0.06)

    // Empty State
    static let emptyStateIconColor      = Color(.tertiaryLabel)
    static let emptyStateTextColor      = Color(.secondaryLabel)

    // Gradients — colorScheme-aware
    static func backgroundGradient(for colorScheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [backgroundGradientStartDark, backgroundGradientEndDark]
                : [backgroundGradientStart, backgroundGradientEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func gridBackgroundGradient(for colorScheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [gridGradientStartDark, gridGradientEndDark]
                : [gridGradientStart, gridGradientEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static let logoGradient = LinearGradient(
        colors: [accentPrimary, accentDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
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

// MARK: - Orbix Card Modifier

struct OrbixCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                    .fill(AppColors.card)
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
