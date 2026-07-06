import SwiftUI

struct ServerRow: View {
    let server: ServerConfig
    var showChevron: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(server.name)
                    Image(systemName: server.https ? "lock.fill" : "lock.open")
                        .font(.caption2)
                        .foregroundStyle(server.https ? Color.green : Color.secondary)
                }
                Text(server.url)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(server.username)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
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
