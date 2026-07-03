import SwiftUI

enum AppTypography {
    // MARK: - Primary Tokens

    /// 34pt Bold — 大标题
    static func titleLarge() -> Font {
        .system(size: 34, weight: .bold)
    }

    /// 22pt Semibold — 中标题 / 卡片标题
    static func titleMedium() -> Font {
        .system(size: 22, weight: .semibold)
    }

    /// 17pt Semibold — 小标题 / 导航标题
    static func titleSmall() -> Font {
        .system(size: 17, weight: .semibold)
    }

    /// 17pt Regular — 正文
    static func body() -> Font {
        .system(size: 17, weight: .regular)
    }

    /// 12pt Regular — 辅助说明 / Caption
    static func caption() -> Font {
        .system(size: 12, weight: .regular)
    }

    // MARK: - Extended

    /// 13pt Regular — 区域标题 / Section Header
    static func sectionHeader() -> Font {
        .system(size: 13, weight: .regular)
    }

    // MARK: - Legacy Aliases

    static func largeTitle() -> Font  { titleLarge() }
    static func cardTitle() -> Font   { titleMedium() }
    static func navTitle() -> Font    { titleSmall() }
    static func subtitle() -> Font    { .system(size: 15, weight: .regular) }
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
    func caption(_ color: Color = AppColors.textSecondary) -> some View {
        self.font(AppTypography.caption()).foregroundColor(color)
    }
    func sectionHeader(_ color: Color = AppColors.textSecondary) -> some View {
        self.font(AppTypography.sectionHeader()).foregroundColor(color)
    }

    // Legacy
    func hero(_ color: Color = AppColors.textPrimary) -> some View {
        self.font(.system(size: 56, weight: .ultraLight)).foregroundColor(color)
    }
    func cardTitle(_ color: Color = AppColors.textPrimary) -> some View {
        titleMedium(color)
    }
    func navTitle(_ color: Color = AppColors.textPrimary) -> some View {
        titleSmall(color)
    }
    func largeTitle(_ color: Color = AppColors.textPrimary) -> some View {
        titleLarge(color)
    }
    func subtitle(_ color: Color = AppColors.textSecondary) -> some View {
        self.font(AppTypography.subtitle()).foregroundColor(color)
    }
}
