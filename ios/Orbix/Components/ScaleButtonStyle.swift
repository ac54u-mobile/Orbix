import SwiftUI

struct ScaleButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.5)
            .animation(AppMotion.fastAnim(), value: configuration.isPressed)
    }
}

#if DEBUG
#Preview {
    Button("Tap") {}.buttonStyle(ScaleButtonStyle())
}
#endif
