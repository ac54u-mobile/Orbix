import SwiftUI

struct ServerSelectionView: View {
    let onConnected: () -> Void

    @State private var servers: [ServerConfig] = []
    @State private var isConnecting = false
    @State private var showLogin = false
    @State private var showManagement = false

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                GlowingLogo(size: 88)

                Text(OrbixStrings.serverSelect)
                    .font(.largeTitle.bold())

                if servers.isEmpty {
                    ContentUnavailableView {
                        Label(OrbixStrings.serverNotAdded, systemImage: "server.rack")
                    } actions: {
                        Button(OrbixStrings.navAddServer) {
                            AppHaptics.light()
                            showLogin = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List(servers) { server in
                        Button {
                            AppHaptics.light()
                            connect(server)
                        } label: {
                            ServerRow(server: server, showChevron: false)
                        }
                    }
                    .listStyle(.insetGrouped)
                }

                Spacer()

                if !servers.isEmpty {
                    Button {
                        showManagement = true
                    } label: {
                        Label(OrbixStrings.btnManageServers, systemImage: "gearshape")
                            .font(.footnote)
                    }
                    .padding(.bottom, 20)
                }
            }
        }
        .onAppear {
            loadServers()
        }
        .sheet(isPresented: $showLogin) {
            LoginView { config in
                servers.append(config)
                connect(config)
            }
        }
        .sheet(isPresented: $showManagement) {
            ServerManagementView(onSelected: { server in
                connect(server)
            })
        }
        .connectingDialog(isPresented: $isConnecting)
    }

    private func loadServers() {
        Task {
            let loaded = await QBitApi.shared.loadServers()
            await MainActor.run { servers = loaded }
        }
    }

    private func connect(_ server: ServerConfig) {
        isConnecting = true
        Task {
            await QBitApi.shared.setActiveServer(server)
            let result = await QBitApi.shared.connect()
            await MainActor.run {
                isConnecting = false
                if result.isSuccess {
                    onConnected()
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    ServerSelectionView(onConnected: {})
}
#endif
