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
                    .titleLarge()

                if servers.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "server.rack")
                            .font(.system(size: 48))
                            .foregroundColor(AppColors.placeholder)

                        Text(OrbixStrings.serverNotAdded)
                            .descriptionSmall()

                        Button {
                            AppHaptics.light()
                            showLogin = true
                        } label: {
                            Text(OrbixStrings.navAddServer)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(AppColors.accentPrimary)
                                        .shadow(color: AppColors.accentPrimary.opacity(0.25), radius: 10, y: 4)
                                )
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                } else {
                    List(servers) { server in
                        Button {
                            AppHaptics.light()
                            connect(server)
                        } label: {
                            ServerRow(server: server, showChevron: false)
                        }
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
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
                        .descriptionSmall(AppColors.accentPrimary)
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
