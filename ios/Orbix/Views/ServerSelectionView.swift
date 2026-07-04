import SwiftUI

struct ServerSelectionView: View {
    let onConnected: () -> Void

    @State private var servers: [ServerConfig] = []
    @State private var isConnecting = false
    @State private var showLogin = false
    @State private var showManagement = false

    var body: some View {
        ZStack {
            AppColors.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                GlowingLogo(size: 88)

                Text(OrbixStrings.serverSelect)
                    .largeTitle()

                if servers.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "server.rack")
                            .font(.system(size: 48))
                            .foregroundColor(AppColors.placeholder)

                        Text(OrbixStrings.serverNotAdded)
                            .subtitle()

                        Button {
                            showLogin = true
                        } label: {
                            Text(OrbixStrings.navAddServer)
                                .bodyFont(AppColors.label)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(AppColors.accent)
                                )
                        }
                    }
                } else {
                    List(servers) { server in
                        Button {
                            connect(server)
                        } label: {
                            ServerRow(server: server, showChevron: false)
                        }
                        .listRowBackground(AppColors.card)
                    }
                    .insetGroupedStyle()
                }

                Spacer()

                if !servers.isEmpty {
                    Button {
                        showManagement = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "gearshape")
                            Text(OrbixStrings.btnManageServers)
                        }
                        .subtitle(AppColors.accent)
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
