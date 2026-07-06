import SwiftUI
import UIKit

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
                    Label(OrbixStrings.tabTorrents, systemImage: "arrow.down.circle.fill")
                }
                .tag(0)

            StatsView()
                .tabItem {
                    Label(OrbixStrings.tabTransfer, systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(1)

            Group {
                if searchMode.use141 {
                    SearchView()
                } else {
                    QBitSearchView()
                }
            }
            .tabItem {
                Label(OrbixStrings.tabSearch, systemImage: "magnifyingglass")
            }
            .tag(2)

            SettingsView(onLogout: onLogout)
                .tabItem {
                    Label(OrbixStrings.tabSettings, systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .tint(.blue)
        .onAppear {
            if let tab = initialTab { selectedTab = tab }
        }
        .onChange(of: selectedTab) { _, _ in
            AppHaptics.light()
        }
    }
}

#if DEBUG
#Preview {
    MainTabView(initialTab: nil, onLogout: {})
}
#endif
