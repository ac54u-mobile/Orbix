import SwiftUI

enum ToastType {
    case neutral
    case success
    case error

    var color: Color {
        switch self {
        case .neutral: return AppColors.elevated
        case .success: return AppColors.success
        case .error: return AppColors.danger
        }
    }
}

struct ToastView: View {
    let type: ToastType
    let message: String

    @State private var isShowing = false

    private var textColor: Color {
        type == .neutral ? .primary : .white
    }

    var body: some View {
        Text(message)
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(textColor)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(type.color)
                    .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 4)
            )
            .opacity(isShowing ? 1 : 0)
            .scaleEffect(isShowing ? 1 : 0.85)
            .onAppear {
                withAnimation(AppMotion.mediumAnim()) {
                    isShowing = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    withAnimation(AppMotion.mediumAnim()) {
                        isShowing = false
                    }
                }
            }
    }
}

#if DEBUG
#Preview {
    ToastView(type: .success, message: "操作完成")
}
#endif

@MainActor
final class ToastManager: ObservableObject {
    static let shared = ToastManager()
    private init() {}

    @Published var isShowing = false
    @Published var message = ""
    @Published var type: ToastType = .neutral

    private var task: Task<Void, Never>?

    func show(_ message: String, type: ToastType = .neutral) {
        task?.cancel()
        self.message = message
        self.type = type
        isShowing = true

        task = Task {
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            if !Task.isCancelled {
                isShowing = false
            }
        }
    }
}
