import SwiftUI

struct ConnectingDialog: View {
    let message: String

    @State private var isVisible = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            AppColors.gridBackgroundGradient(for: colorScheme).opacity(0.6)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(AppColors.accentPrimary)

                Text(message)
                    .bodyFont()
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 32)
            .liquidGlass(.thick)
            .scaleEffect(isVisible ? 1 : 0.8)
            .opacity(isVisible ? 1 : 0)
        }
        .onAppear {
            withAnimation(AppMotion.mediumAnim()) {
                isVisible = true
            }
        }
    }
}

#if DEBUG
#Preview {
    ConnectingDialog(message: OrbixStrings.msgConnecting)
}
#endif

struct ConnectingDialogModifier: ViewModifier {
    @Binding var isPresented: Bool
    var message: String

    func body(content: Content) -> some View {
        content
            .overlay {
                if isPresented {
                    ConnectingDialog(message: message)
                        .transition(.opacity)
                        .zIndex(100)
                }
            }
            .animation(AppMotion.fastAnim(), value: isPresented)
    }
}

extension View {
    func connectingDialog(isPresented: Binding<Bool>, message: String = OrbixStrings.msgConnecting) -> some View {
        modifier(ConnectingDialogModifier(isPresented: isPresented, message: message))
    }
}
