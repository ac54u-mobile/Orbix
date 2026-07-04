import SwiftUI

struct DetailRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    var valueColor: Color = .secondary

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(iconColor.opacity(0.13))
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            .frame(width: 28, height: 28)

            Text(label)
                .font(.system(size: 15))
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .font(.system(size: 15, design: .monospaced))
                .foregroundColor(valueColor)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }
}

#if DEBUG
#Preview {
    DetailRow(icon: "arrow.down", iconColor: .blue, label: "下载速度", value: "10.5 MB/s")
}
#endif
