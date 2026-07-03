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

    /// 17pt Semibold — 小标题 / 列表项标题
    static func titleSmall() -> Font {
        .system(size: 17, weight: .semibold)
    }

    /// 17pt Semibold — 列表项名称 (等同 titleSmall，语义别名)
    static func listTitleMedium() -> Font {
        titleSmall()
    }

    /// 17pt Regular — 正文
    static func body() -> Font {
        .system(size: 17, weight: .regular)
    }

    /// 13pt Regular — 描述文字
    static func descriptionSmall() -> Font {
        .system(size: 13, weight: .regular)
    }

    /// 12pt Regular — 辅助说明
    static func caption() -> Font {
        .system(size: 12, weight: .regular)
    }

    /// 11pt Semibold — 标签文字（如 "新"、"建议"）
    static func tagCaption() -> Font {
        .system(size: 11, weight: .semibold)
    }

    // MARK: - Extended

    static func sectionHeader() -> Font {
        descriptionSmall()
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
