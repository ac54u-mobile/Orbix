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

    static let spring: Animation        = .spring(response: 0.4, dampingFraction: 0.8)
    static let springSnappy: Animation  = .spring(response: 0.3, dampingFraction: 0.75)
    static let springGentle: Animation  = .spring(response: 0.55, dampingFraction: 0.85)
    static let interactive: Animation   = .interactiveSpring(response: 0.28, dampingFraction: 0.86)

    static let draggingCurve: Animation = .spring(response: 0.15, dampingFraction: 1.0)

    static let breathingScale: Animation = .timingCurve(0.2, 0.0, 0.2, 1.0, duration: 0.15)

    static let skeletonCycle: TimeInterval = 1.4
    static let shimmerDuration: TimeInterval = 1.2
}

// MARK: - Scale Button Style

struct ScaleButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.5)
            .animation(AppMotion.breathingScale, value: configuration.isPressed)
    }
}

// MARK: - Unified Haptic Feedback

enum AppHaptics {
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func heavy() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    static func soft() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    static func breathing() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred(intensity: 0.3)
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 20) {
        Button("Tap") {}.buttonStyle(ScaleButtonStyle())
        Button("Disabled") {}.buttonStyle(ScaleButtonStyle()).disabled(true)
    }
    .padding()
}
#endif
