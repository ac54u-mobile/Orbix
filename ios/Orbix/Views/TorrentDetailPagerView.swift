import SwiftUI

struct TorrentDetailPagerView: View {
    let hashes: [String]
    @State private var currentHash: String
    @Environment(\.colorScheme) private var colorScheme

    init(hashes: [String], initialHash: String) {
        self.hashes = hashes
        self._currentHash = State(initialValue: initialHash)
    }

    var body: some View {
        TabView(selection: $currentHash) {
            ForEach(hashes, id: \.self) { hash in
                Group {
                    if shouldLoad(hash) {
                        TorrentDetailView(hash: hash)
                    } else {
                        AppColors.gridBackgroundGradient.ignoresSafeArea()
                            .overlay {
                                ProgressView()
                                    .tint(AppColors.textTertiary)
                            }
                    }
                }
                .tag(hash)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea(edges: .bottom)
        .animation(AppMotion.draggingCurve, value: currentHash)
        .onChange(of: currentHash) { _, _ in
            AppHaptics.light()
        }
        .safeAreaInset(edge: .bottom) {
            if hashes.count > 1 {
                pageIndicator
            }
        }
    }

    private func shouldLoad(_ hash: String) -> Bool {
        guard let current = hashes.firstIndex(of: currentHash),
              let index = hashes.firstIndex(of: hash) else { return hash == currentHash }
        return abs(current - index) <= 1
    }

    private var pageIndicator: some View {
        Text("\(currentIndexDisplay) / \(hashes.count)")
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundColor(AppColors.textSecondary)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 5)
            .background(Capsule().fill(AppColors.glassThick(for: colorScheme)))
            .padding(.bottom, 4)
            .transition(.opacity)
    }

    private var currentIndexDisplay: Int {
        (hashes.firstIndex(of: currentHash) ?? 0) + 1
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        TorrentDetailPagerView(hashes: ["a", "b", "c"], initialHash: "a")
    }
}
#endif
