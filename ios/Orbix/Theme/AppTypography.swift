import SwiftUI

enum AppTypography {
    static func hero() -> Font {
        .system(size: 56, weight: .ultraLight, design: .default)
            .monospacedDigit()
    }

    static func navTitle() -> Font {
        .system(size: 17, weight: .semibold)
    }

    static func largeTitle() -> Font {
        .system(size: 34, weight: .bold)
    }

    static func cardTitle() -> Font {
        .system(size: 22, weight: .bold)
    }

    static func sectionHeader() -> Font {
        .system(size: 13, weight: .regular)
    }

    static func body() -> Font {
        .system(size: 17, weight: .regular)
    }

    static func subtitle() -> Font {
        .system(size: 15, weight: .regular)
    }

    static func caption() -> Font {
        .system(size: 12, weight: .medium)
    }
}

extension View {
    func hero(_ color: Color = AppColors.label) -> some View {
        self.font(AppTypography.hero())
            .foregroundColor(color)
    }
    func navTitle(_ color: Color = AppColors.label) -> some View {
        self.font(AppTypography.navTitle())
            .foregroundColor(color)
    }
    func largeTitle(_ color: Color = AppColors.label) -> some View {
        self.font(AppTypography.largeTitle())
            .foregroundColor(color)
    }
    func cardTitle(_ color: Color = AppColors.label) -> some View {
        self.font(AppTypography.cardTitle())
            .foregroundColor(color)
    }
    func sectionHeader(_ color: Color = AppColors.secondaryLabel) -> some View {
        self.font(AppTypography.sectionHeader())
            .foregroundColor(color)
    }
    func bodyFont(_ color: Color = AppColors.label) -> some View {
        self.font(AppTypography.body())
            .foregroundColor(color)
    }
    func subtitle(_ color: Color = AppColors.secondaryLabel) -> some View {
        self.font(AppTypography.subtitle())
            .foregroundColor(color)
    }
    func caption(_ color: Color = AppColors.tertiaryLabel) -> some View {
        self.font(AppTypography.caption())
            .foregroundColor(color)
    }
}
