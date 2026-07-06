import SwiftUI

enum AppTypography {
    // MARK: - HIG Semantic Tokens (Dynamic Type native via Apple built-in styles)

    static func titleLarge() -> Font { .largeTitle }
    static func titleMedium() -> Font { .title2 }
    static func titleSmall() -> Font { .headline }
    static func body() -> Font { .body }
    static func descriptionSmall() -> Font { .footnote }
    static func caption() -> Font { .caption }
    static func tagCaption() -> Font { .caption2 }
    static func sectionHeader() -> Font { .footnote }

    // MARK: - Custom Semantic Tokens

    static func heroProgress() -> Font {
        .system(size: 42, weight: .bold, design: .rounded)
    }

    static func monoValue() -> Font {
        .system(.body, design: .monospaced)
    }

    static func detailHeadline() -> Font {
        .system(.callout)
    }

    static func filterLabel() -> Font {
        .system(size: 14, weight: .semibold)
    }

    // Legacy
    static func hero() -> Font {
        .system(size: 56, weight: .ultraLight)
    }
}

// MARK: - View Extensions (Dynamic Type native)

extension View {
    func titleLarge(_ color: Color = AppColors.textPrimary) -> some View {
        self.font(AppTypography.titleLarge()).foregroundColor(color)
    }
    func titleMedium(_ color: Color = AppColors.textPrimary) -> some View {
        self.font(AppTypography.titleMedium()).foregroundColor(color)
    }
    func titleSmall(_ color: Color = AppColors.textPrimary) -> some View {
        self.font(AppTypography.titleSmall()).foregroundColor(color)
    }
    func bodyFont(_ color: Color = AppColors.textPrimary) -> some View {
        self.font(AppTypography.body()).foregroundColor(color)
    }
    func descriptionSmall(_ color: Color = AppColors.textSecondary) -> some View {
        self.font(AppTypography.descriptionSmall()).foregroundColor(color)
    }
    func caption(_ color: Color = AppColors.textSecondary) -> some View {
        self.font(AppTypography.caption()).foregroundColor(color)
    }
    func tagCaption(_ color: Color = AppColors.textPrimary) -> some View {
        self.font(AppTypography.tagCaption()).foregroundColor(color)
    }
    func sectionHeader(_ color: Color = AppColors.textSecondary) -> some View {
        self.font(AppTypography.sectionHeader()).foregroundColor(color)
    }
    func heroProgress(_ color: Color = AppColors.textPrimary) -> some View {
        self.font(AppTypography.heroProgress()).foregroundColor(color)
    }
    func monoValue(_ color: Color = AppColors.textPrimary) -> some View {
        self.font(AppTypography.monoValue()).foregroundColor(color)
    }
    func detailHeadline(_ color: Color = AppColors.textPrimary) -> some View {
        self.font(AppTypography.detailHeadline()).foregroundColor(color)
    }

    func iconSymbol(_ color: Color = AppColors.textPrimary) -> some View {
        self
            .font(.system(size: 14, weight: .semibold))
            .frame(width: IconLayout.sfSymbolSize, height: IconLayout.sfSymbolSize)
            .foregroundColor(color)
    }

    // Legacy
    func hero(_ color: Color = AppColors.textPrimary) -> some View {
        self.font(AppTypography.hero()).foregroundColor(color)
    }
}
