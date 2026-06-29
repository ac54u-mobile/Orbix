import SwiftUI

struct SolidCardButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && isEnabled ? 0.98 : 1)
            .opacity(isEnabled ? 1 : 0.5)
            .animation(AppMotion.fastAnim(), value: configuration.isPressed)
    }
}

#if DEBUG
#Preview {
    Button("Tap") {}.buttonStyle(SolidCardButtonStyle())
}
#endif
