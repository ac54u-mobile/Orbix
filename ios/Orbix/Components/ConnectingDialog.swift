import SwiftUI

struct ConnectingDialog: View {
    let message: String

    @State private var isVisible = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)

                Text(message)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 32)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .scaleEffect(isVisible ? 1 : 0.8)
            .opacity(isVisible ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
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
            .animation(.easeOut(duration: 0.22), value: isPresented)
    }
}

extension View {
    func connectingDialog(isPresented: Binding<Bool>, message: String = OrbixStrings.msgConnecting) -> some View {
        modifier(ConnectingDialogModifier(isPresented: isPresented, message: message))
    }
}
