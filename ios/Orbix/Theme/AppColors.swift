import SwiftUI

// MARK: - Color Palette

enum AppColors {
    // Background
    static let backgroundBase          = Color(red: 0.97, green: 0.96, blue: 0.98)
    static let backgroundGradientStart = Color(red: 1.0,  green: 0.94, blue: 0.97)
    static let backgroundGradientEnd   = Color(red: 0.90, green: 0.95, blue: 1.0)

    // Surface / Card — 浅色毛玻璃卡片
    static let card                     = Color.white.opacity(0.85)
    static let elevated                 = Color.white

    // Text — 系统语义色，自动保证对比度
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

    // Separator / Border / Divider
    static let listDivider              = Color(.separator)
    static let separator                = listDivider
    static let placeholder              = Color(.placeholderText)

    // Skeleton
    static let skeletonBase             = Color(.systemGray5)
    static let skeletonHighlight        = Color(.systemGray6)

    // Glass / Translucent
    static let glassBorder              = Color.black.opacity(0.06)

    // Gradients
    static let backgroundGradient = LinearGradient(
        colors: [backgroundGradientStart, backgroundGradientEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
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
