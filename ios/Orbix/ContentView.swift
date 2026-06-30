import SwiftUI

struct ContentView: View {
    @State private var destination: Destination = .splash
    @State private var showLoginFromWelcome = false
    @State private var deepLinkTab: Int?

    enum Destination {
        case splash
        case welcome
        case serverSelection
        case main
    }

    var body: some View {
        VStack(spacing: 0) {
            switch destination {
            case .splash:
                SplashView(onDecision: { decision in
                    withAnimation(AppMotion.standardCurve) {
                        destination = decision
                    }
                })
            case .welcome:
                WelcomeView(onAddServer: {
                    showLoginFromWelcome = true
                })
                .sheet(isPresented: $showLoginFromWelcome) {
                    LoginView { config in
                        showLoginFromWelcome = false
                        let cred = ServiceCredential(
                            kind: .qBittorrent,
                            name: config.name,
                            host: config.host,
                            port: config.port,
                            https: config.https,
                            apiKey: "",
                            username: config.username,
                            password: config.password
                        )
                        CredentialsManager.shared.save(cred)
                        Task {
                            await QBitApi.shared.setActiveServer(config)
                            _ = await QBitApi.shared.connect()
                            await MainActor.run {
                                withAnimation(AppMotion.standardCurve) {
                                    destination = .main
                                }
                            }
                        }
                    }
                }
            case .serverSelection:
                ServerSelectionView(onConnected: {
                    withAnimation(AppMotion.standardCurve) {
                        destination = .main
                    }
                })
            case .main:
                MainTabView(initialTab: deepLinkTab, onLogout: {
                    deepLinkTab = nil
                    withAnimation(AppMotion.standardCurve) {
                        destination = .serverSelection
                    }
                })
            }
        }
        .animation(AppMotion.standardCurve, value: destination)
        .onOpenURL { _ in navigateToSearch() }
        .onReceive(NotificationCenter.default.publisher(for: .openSearch)) { _ in navigateToSearch() }
        .onAppear {
            if AppDelegate.pendingShortcut == "search" {
                AppDelegate.pendingShortcut = nil
                navigateToSearch()
            }
        }
    }

    private func navigateToSearch() {
        deepLinkTab = 2
    }
}
