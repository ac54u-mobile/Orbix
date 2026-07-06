import SwiftUI

// MARK: - iOS 26 Liquid Glass Design System

enum AppColors {
    // MARK: Background — Vibrant Base (shows through glass)
    // Light Mode
    static let backgroundBase           = Color(hex: "#F2F1F7")
    static let backgroundGradientStart  = Color(hex: "#E8E4F0")
    static let backgroundGradientEnd    = Color(hex: "#DEE8F5")
    static let gridGradientStart        = Color(hex: "#EDE8F3")
    static let gridGradientEnd          = Color(hex: "#DCE4F2")

    // Dark Mode — deep vibrant tones that make glass pop
    static let backgroundGradientStartDark = Color(hex: "#0D0D1A")
    static let backgroundGradientEndDark   = Color(hex: "#101828")
    static let gridGradientStartDark       = Color(hex: "#0F0F1E")
    static let gridGradientEndDark         = Color(hex: "#121A2C")

    // Old pastel tokens — kept for backward compatibility
    static let backgroundGradientStartLight_Legacy = Color(red: 0.996, green: 0.949, blue: 0.965)
    static let backgroundGradientEndLight_Legacy   = Color(red: 0.941, green: 0.957, blue: 1.0)
    static let gridGradientStartLight_Legacy       = Color(hex: "#FEF2F6")
    static let gridGradientEndLight_Legacy         = Color(hex: "#F0F4FE")

    // MARK: Liquid Glass Surface Layers
    // Thickness levels — higher = more opaque, more elevated

    /// Glass level 0 — near-transparent, for subtle background overlays
    static func glassThin(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.04)
            : Color.white.opacity(0.35)
    }

    /// Glass level 1 — standard card surface
    static func glassRegular(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.06)
            : Color.white.opacity(0.50)
    }

    /// Glass level 2 — elevated surface (sheets, dialogs)
    static func glassThick(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.09)
            : Color.white.opacity(0.65)
    }

    /// Glass level 3 — highest elevation (navigation bars, tab bars)
    static func glassChrome(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.12)
            : Color.white.opacity(0.80)
    }

    // MARK: Glass Borders
    static func glassBorder(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.06)
            : Color.white.opacity(0.40)
    }

    static func glassBorderSubtle(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.03)
            : Color.white.opacity(0.20)
    }

    // Legacy static glass border — light mode default
    static let glassBorder = Color.primary.opacity(0.06)

    // MARK: Surface (backward-compatible with old code)
    static let card     = Color(.systemBackground).opacity(0.6)
    static let elevated = Color(.systemBackground).opacity(0.72)

    // MARK: Text
    static let textPrimary   = Color(.label)
    static let textSecondary = Color(.secondaryLabel)
    static let textTertiary  = Color(.tertiaryLabel)

    // MARK: Accent
    static let accentPrimary = Color(hex: "#007AFF")
    static let accentDark    = Color(hex: "#0056D6")
    static let accentSoftBg  = Color(hex: "#E8F1FF")

    // MARK: Semantic
    static let success = Color(hex: "#34C759")
    static let warning = Color(hex: "#FF9500")
    static let danger  = Color(hex: "#FF3B30")

    // MARK: System mappings
    static let tagBackgroundGreen = Color(hex: "#34C759")
    static let tagBackgroundBlue  = Color(hex: "#409CFF")
    static let statsWaveform      = Color(hex: "#34C759")
    static let listDivider        = Color(.separator)
    static let separator          = listDivider
    static let hairlineDivider    = Color.primary.opacity(0.08)
    static let placeholder        = Color(.placeholderText)
    static let skeletonBase       = Color(.systemGray5)
    static let skeletonHighlight  = Color(.systemGray6)
    static let emptyStateIconColor = Color(.tertiaryLabel)
    static let emptyStateTextColor = Color(.secondaryLabel)

    // Gradients — Light mode defaults (backward-compatible)
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

    // Gradients — ColorScheme-aware variants
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

// MARK: - Orbix Card Modifier (now powered by Liquid Glass)

struct OrbixCard: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                    .fill(AppColors.glassRegular(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                    .stroke(AppColors.glassBorder(for: colorScheme), lineWidth: 0.5)
            )
    }
}

extension View {
    func orbixCard() -> some View {
        modifier(OrbixCard())
    }
}
