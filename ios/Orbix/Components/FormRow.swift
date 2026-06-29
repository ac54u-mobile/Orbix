import SwiftUI

struct FormRow<Content: View>: View {
    let icon: String
    let title: String
    let content: Content

    init(icon: String, title: String, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.title = title
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(AppColors.secondaryLabel)
                .frame(width: 24, alignment: .center)

            VStack(alignment: .leading, spacing: 0) {
                    content
                        .font(.system(size: 15))
            }
        }
        .padding(.vertical, 1)
    }
}

struct IconTextFieldRow: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var disableAutocap: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(AppColors.secondaryLabel)
                .frame(width: 24)

            TextField(placeholder, text: $text)
                .font(.system(size: 15))
                .foregroundColor(AppColors.label)
                .textInputAutocapitalization(disableAutocap ? .never : .sentences)
                .disableAutocorrection(disableAutocap)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
