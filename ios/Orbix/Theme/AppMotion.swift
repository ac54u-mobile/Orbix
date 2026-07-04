import SwiftUI
import UIKit

enum AppMotion {
    static let standardCurve: Animation = .timingCurve(0.2, 0.8, 0.2, 1.0, duration: 0.35)

    static let fast: TimeInterval = 0.22
    static let medium: TimeInterval = 0.35
    static let slow: TimeInterval = 0.45

    static func fastAnim() -> Animation {
        .timingCurve(0.2, 0.8, 0.2, 1.0, duration: fast)
    }

    static func mediumAnim() -> Animation {
        .timingCurve(0.2, 0.8, 0.2, 1.0, duration: medium)
    }

    static func slowAnim() -> Animation {
        .timingCurve(0.2, 0.8, 0.2, 1.0, duration: slow)
    }

    // 弹簧物理曲线 — 跟手、自然、符合物理直觉
    static let spring: Animation        = .spring(response: 0.4, dampingFraction: 0.8)
    static let springSnappy: Animation  = .spring(response: 0.3, dampingFraction: 0.75)
    static let springGentle: Animation  = .spring(response: 0.55, dampingFraction: 0.85)
    static let interactive: Animation   = .interactiveSpring(response: 0.28, dampingFraction: 0.86)

    static let skeletonCycle: TimeInterval = 1.4
}

// MARK: - 统一触觉反馈层
// 集中管理全应用的 Haptic，保证反馈强度语义一致

enum AppHaptics {
    /// 轻触 — 选择切换、滚动吸附
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// 轻击 — 次要按钮、翻页
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// 中击 — 主要操作确认
    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// 重击 — 破坏性操作（删除、清空）
    static func heavy() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    /// 柔和 — 手势跟随过程中的阻尼提示
    static func soft() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    /// 成功 — 操作完成
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// 警告 — 边界、需要注意
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    /// 失败 — 操作出错
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
