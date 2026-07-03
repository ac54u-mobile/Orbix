import SwiftUI

// MARK: - Color Palette

enum AppColors {
    // Background
    static let backgroundBase          = Color(hex: "#0A0C1F")
    static let backgroundGradientStart = Color(hex: "#1C003D")
    static let backgroundGradientEnd   = Color(hex: "#00122B")

    // Surface / Card
    static let card                     = Color(hex: "#11132B")
    static let elevated                 = Color(hex: "#181B37")

    // Text
    static let textPrimary              = Color(hex: "#FFFFFF")
    static let textSecondary            = Color(hex: "#C0C0C8")
    static let textTertiary             = Color(hex: "#8E8E98")

    // Accent
    static let accentPrimary            = Color(hex: "#007AFF")
    static let accentDark               = Color(hex: "#0056D6")
    static let accentSoftBg             = Color(hex: "#1A1F3D")

    // Tag Backgrounds
    static let tagBackgroundGreen       = Color(hex: "#34C759")
    static let tagBackgroundBlue        = Color(hex: "#409CFF")

    // Semantic
    static let success                  = Color(hex: "#34C759")
    static let warning                  = Color(hex: "#FF9500")
    static let danger                   = Color(hex: "#FF3B30")

    // Chart / Waveform
    static let statsWaveform            = Color(hex: "#34C759")

    // Separator / Border / Divider
    static let listDivider              = Color(hex: "#303038")
    static let separator                = listDivider
    static let placeholder              = Color(hex: "#6B6D80")

    // Skeleton
    static let skeletonBase             = Color(hex: "#181B37")
    static let skeletonHighlight        = Color(hex: "#24284A")

    // Glass / Translucent
    static let glassBorder              = Color.white.opacity(0.05)

    // Gradients
    static let backgroundGradient = LinearGradient(
        colors: [backgroundGradientStart, backgroundGradientEnd],
        startPoint: .top,
        endPoint: .bottom
    )

    static let logoGradient = LinearGradient(
        colors: [accentPrimary, accentDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Legacy aliases
    static let groupedBg         = backgroundBase
    static let mainBg            = backgroundBase
    static let plainBg           = card
    static let label             = textPrimary
    static let secondaryLabel    = textSecondary
    static let tertiaryLabel     = textTertiary
    static let accent            = accentPrimary
}

// MARK: - Layout Constants

enum AppRadius {
    static let xs: CGFloat  = 2
    static let sm: CGFloat  = 6
    static let md: CGFloat  = 10
    static let lg: CGFloat  = 14
    static let xl: CGFloat  = 18
    static let xxl: CGFloat = 24
}

enum AppSpacing {
    static let xs: CGFloat  = 4
    static let sm: CGFloat  = 8
    static let md: CGFloat  = 12
    static let lg: CGFloat  = 16
    static let xl: CGFloat  = 20
    static let xxl: CGFloat = 24
}

// MARK: - Page Layout Configs

enum SettingsConfig {
    static let containerCornerRadius: CGFloat = 14.0
    static let listRowHeight: CGFloat         = 72.0
    static let overallSpacing: CGFloat        = 16.0
    static let itemContentSpacing: CGFloat    = 12.0
    static let iconSize: CGSize               = CGSize(width: 24, height: 24)
}

enum StatsViewConfig {
    static let containerCornerRadius: CGFloat   = 14.0
    static let listRowHeight: CGFloat           = 72.0
    static let elementSpacing: CGFloat          = 16.0
    static let waveformWidthMultiplier: CGFloat = 0.8
}

// MARK: - Card Modifier

struct TeslaCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                    .fill(AppColors.card.opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                    .stroke(AppColors.glassBorder, lineWidth: 1)
            )
    }
}

extension View {
    func teslaCard() -> some View {
        modifier(TeslaCard())
    }
}
