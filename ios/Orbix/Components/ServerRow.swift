import SwiftUI

struct ServerRow: View {
    let server: ServerConfig
    var showChevron: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(server.name)
                        .bodyFont()
                    Image(systemName: server.https ? "lock.fill" : "lock.open")
                        .font(.caption2)
                        .foregroundColor(server.https ? AppColors.success : AppColors.textSecondary)
                }
                Text(server.url)
                    .descriptionSmall()
                Text(server.username)
                    .caption()
            }

            Spacer()

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

#if DEBUG
#Preview {
    ServerRow(server: ServerConfig(
        name: "Home NAS",
        host: "192.168.1.100",
        port: 8080,
        username: "admin",
        password: "",
        https: true
    ))
    .padding()
}
#endif
