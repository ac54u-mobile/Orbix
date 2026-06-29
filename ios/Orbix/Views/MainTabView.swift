import SwiftUI

final class SearchModeState: ObservableObject {
    @Published var use141: Bool = false
    static let shared = SearchModeState()
}

struct MainTabView: View {
    let initialTab: Int?
    let onLogout: () -> Void

    @State private var selectedTab = 0
    @ObservedObject private var searchMode = SearchModeState.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            TorrentListView()
                .tabItem {
                    Image(systemName: "square.stack")
                    Text(OrbixStrings.tabTorrents)
                }
                .tag(0)
                .accessibilityLabel(OrbixStrings.tabTorrents)

            StatsView()
                .tabItem {
                    Image(systemName: "chart.bar")
                    Text(OrbixStrings.tabTransfer)
                }
                .tag(1)
                .accessibilityLabel(OrbixStrings.tabTransfer)

            Group {
                if searchMode.use141 {
                    SearchView()
                } else {
                    QBitSearchView()
                }
            }
            .tabItem {
                Image(systemName: searchMode.use141 ? "magnifyingglass.circle.fill" : "magnifyingglass")
                Text(OrbixStrings.tabSearch)
            }
            .tag(2)
            .accessibilityLabel(OrbixStrings.tabSearch)

            SettingsView(onLogout: onLogout)
                .tabItem {
                    Image(systemName: "gearshape")
                    Text(OrbixStrings.tabSettings)
                }
                .tag(3)
                .accessibilityLabel(OrbixStrings.tabSettings)
        }
        .tint(AppColors.accent)
        .onAppear {
            if let tab = initialTab { selectedTab = tab }
        }
    }
}

#if DEBUG
#Preview {
    MainTabView(initialTab: nil, onLogout: {})
}
#endif
