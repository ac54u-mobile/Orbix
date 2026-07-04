import SwiftUI

enum AppTypography {
    // MARK: - HIG Semantic Tokens

    static func titleLarge() -> Font {
        .system(size: 34, weight: .bold)
    }

    static func titleMedium() -> Font {
        .system(size: 22, weight: .semibold)
    }

    static func titleSmall() -> Font {
        .system(size: 17, weight: .semibold)
    }

    static func body() -> Font {
        .system(size: 17, weight: .regular)
    }

    static func descriptionSmall() -> Font {
        .system(size: 13, weight: .regular)
    }

    static func caption() -> Font {
        .system(size: 12, weight: .regular)
    }

    static func tagCaption() -> Font {
        .system(size: 11, weight: .semibold)
    }

    // MARK: - Extended

    static func sectionHeader() -> Font {
        descriptionSmall()
    }
}

// MARK: - View Extensions

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

    func iconSymbol(_ color: Color = AppColors.textPrimary) -> some View {
        self
            .font(.system(size: 14, weight: .semibold))
            .frame(width: IconLayout.sfSymbolSize, height: IconLayout.sfSymbolSize)
            .foregroundColor(color)
    }

    // Legacy
    func hero(_ color: Color = AppColors.textPrimary) -> some View {
        self.font(.system(size: 56, weight: .ultraLight)).foregroundColor(color)
    }
}
