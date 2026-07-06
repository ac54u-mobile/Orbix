import SwiftUI
import UIKit

enum SearchSource: String, CaseIterable {
    case radarr
    case ppv141

    var displayName: String {
        switch self {
        case .radarr: return "Radarr"
        case .ppv141: return "141PPV"
        }
    }

    var icon: String {
        switch self {
        case .radarr: return "movieclapper"
        case .ppv141: return "network"
        }
    }
}

final class SearchModeState: ObservableObject {
    @Published var source: SearchSource = .radarr
    static let shared = SearchModeState()
}

/// 搜索来源切换菜单（三个搜索页共用）
struct SearchSourceMenu: View {
    @ObservedObject private var searchMode = SearchModeState.shared

    var body: some View {
        Menu {
            Picker(String(localized: "搜索来源", comment: "Search source"), selection: $searchMode.source) {
                ForEach(SearchSource.allCases, id: \.self) { source in
                    Label(source.displayName, systemImage: source.icon)
                        .tag(source)
                }
            }
        } label: {
            Image(systemName: searchMode.source.icon)
        }
        .accessibilityLabel(String(localized: "切换搜索来源", comment: "Switch search source"))
    }
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
                switch searchMode.source {
                case .radarr: RadarrSearchView()
                case .ppv141: SearchView()
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
