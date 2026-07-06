import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: icon)
        } description: {
            Text(subtitle)
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle) {
                    AppHaptics.light()
                    action()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

#if DEBUG
#Preview {
    EmptyStateView(
        icon: "tray",
        title: "No Items",
        subtitle: "There's nothing here yet.",
        actionTitle: "Add Something",
        action: {}
    )
}
#endif
