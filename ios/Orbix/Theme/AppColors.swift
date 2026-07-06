import SwiftUI

// MARK: - Semantic Color Tokens

enum AppColors {
    // Background
    static let backgroundBase          = Color(red: 0.95, green: 0.96, blue: 0.98)
    static let backgroundGradientStart = Color(red: 0.95, green: 0.96, blue: 0.98)
    static let backgroundGradientEnd   = Color(red: 0.91, green: 0.94, blue: 0.98)
    static let gridGradientStart       = Color(hex: "#EDF1F7")
    static let gridGradientEnd         = Color(hex: "#E4EAF2")

    // Surface
    static let card                     = Color(.systemBackground).opacity(0.78)
    static let elevated                 = Color(.systemBackground).opacity(0.85)

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

    // Gradients
    static let backgroundGradient = LinearGradient(
        colors: [backgroundGradientStart, backgroundGradientEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let gridBackgroundGradient = LinearGradient(
        colors: [gridGradientStart, gridGradientEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

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
