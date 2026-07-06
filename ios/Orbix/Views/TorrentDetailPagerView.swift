import SwiftUI

struct TorrentDetailPagerView: View {
    let hashes: [String]
    @State private var currentHash: String

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
                        Color(.systemGroupedBackground).ignoresSafeArea()
                            .overlay {
                                ProgressView()
                            }
                    }
                }
                .tag(hash)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea(edges: .bottom)
        .animation(.spring(response: 0.15, dampingFraction: 1.0), value: currentHash)
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
            .font(.system(.caption, design: .monospaced).weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(.regularMaterial, in: Capsule())
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
