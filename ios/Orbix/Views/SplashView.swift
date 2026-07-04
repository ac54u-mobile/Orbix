import SwiftUI

struct SplashView: View {
    let onDecision: (ContentView.Destination) -> Void

    @State private var isAnimating = false
    @State private var statusMessage: String?

    var body: some View {
        ZStack {
            AppColors.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 20) {
                GlowingLogo(size: 88)
                    .scaleEffect(isAnimating ? 1 : 0.6)
                    .opacity(isAnimating ? 1 : 0)

                Text("Orbix")
                    .titleLarge()
                    .opacity(isAnimating ? 1 : 0)
                    .offset(y: isAnimating ? 0 : 20)

                if let msg = statusMessage {
                    Text(msg)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.warning)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                        .opacity(isAnimating ? 1 : 0)
                }

                ProgressView()
                    .tint(AppColors.textSecondary)
                    .padding(.top, 40)
                    .opacity(isAnimating ? 1 : 0)
            }
            .padding(.horizontal, 40)
        }
        .onAppear {
            withAnimation(AppMotion.slowAnim()) {
                isAnimating = true
            }

            Task {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                await decideDestination()
            }
        }
    }

    private func decideDestination() async {
        // Migrate existing qBittorrent servers into CredentialsManager
        if CredentialsManager.shared.qBittorrent == nil {
            let servers = await QBitApi.shared.loadServers()
            if let saved = await QBitApi.shared.loadSavedConfig() ?? servers.first {
                let cred = ServiceCredential(
                    kind: .qBittorrent, name: saved.name, host: saved.host,
                    port: saved.port, https: saved.https, apiKey: "",
                    username: saved.username, password: saved.password
                )
                CredentialsManager.shared.save(cred)
            }
        }

        // 1. No services at all → first launch
        if CredentialsManager.shared.activeServices.isEmpty {
            onDecision(.welcome)
            return
        }

        // Sync CredentialsManager → QBitApi so connection works
        if let qbitCred = CredentialsManager.shared.qBittorrent {
            let config = ServerConfig(
                name: qbitCred.name, host: qbitCred.host, port: qbitCred.port,
                username: qbitCred.username, password: qbitCred.password,
                https: qbitCred.https
            )
            await QBitApi.shared.setActiveServer(config)
            _ = await QBitApi.shared.upsertServer(config)
        }

        // 2. qBittorrent configured → try connect
        let servers = await QBitApi.shared.loadServers()
        if !servers.isEmpty, let active = await QBitApi.shared.loadSavedConfig() {
            await QBitApi.shared.setActiveServer(active)
            let result = await QBitApi.shared.connect()
            if result.isSuccess {
                onDecision(.main)
                return
            }
            statusMessage = String(format: String(localized: "连接失败: %@\n请检查服务器配置", comment: "Connection failed, check server config"), result.message)
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            onDecision(.serverSelection)
            return
        }

        // 3. Other services exist but no qBittorrent → still let user in
        onDecision(.main)
    }
}

#if DEBUG
#Preview {
    SplashView(onDecision: { _ in })
}
#endif
