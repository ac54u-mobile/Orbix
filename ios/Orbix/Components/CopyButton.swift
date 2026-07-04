import SwiftUI

struct CopyButton: View {
    let textToCopy: String
    @State private var copied = false

    var body: some View {
        Button {
            UIPasteboard.general.string = textToCopy
            AppHaptics.success()

            withAnimation { copied = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { copied = false }
            }
        } label: {
            Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                .font(.system(size: 14))
                .foregroundColor(copied ? AppColors.success : AppColors.accent)
                .padding(4)
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
#Preview {
    CopyButton(textToCopy: "abc123def")
}
#endif
