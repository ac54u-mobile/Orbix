import SwiftUI

extension View {
    func toast(isPresented: Binding<Bool>, type: ToastType = .neutral, message: String) -> some View {
        self.overlay(alignment: .top) {
            if isPresented.wrappedValue {
                ToastView(type: type, message: message)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 60)
                    .zIndex(100)
            }
        }
    }
}

extension View {
    func onBackground(_ perform: @escaping () -> Void) -> some View {
        self.onReceive(
            NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification),
            perform: { _ in perform() }
        )
    }

    func onForeground(_ perform: @escaping () -> Void) -> some View {
        self.onReceive(
            NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification),
            perform: { _ in perform() }
        )
    }
}
