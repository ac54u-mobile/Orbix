import SwiftUI

/// 相册式滑动详情容器 — 像浏览照片一样左右滑动切换种子详情。
/// 跟手的分页手势 + 切页触觉反馈；仅渲染当前页与相邻页，保证性能。
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
                        // 占位，滑近时才真正加载，避免同时轮询所有页面
                        AppColors.backgroundGradient.ignoresSafeArea()
                    }
                }
                .tag(hash)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea(edges: .bottom)
        .onChange(of: currentHash) { _, _ in
            AppHaptics.selection()
        }
        .safeAreaInset(edge: .bottom) {
            if hashes.count > 1 {
                pageIndicator
            }
        }
    }

    /// 只保留当前页 ±1 的实体视图，其余用轻量占位
    private func shouldLoad(_ hash: String) -> Bool {
        guard let current = hashes.firstIndex(of: currentHash),
              let index = hashes.firstIndex(of: hash) else { return hash == currentHash }
        return abs(current - index) <= 1
    }

    /// 轻盈的位置指示 — 文字代替圆点，不喧宾夺主
    private var pageIndicator: some View {
        Text("\(currentIndexDisplay) / \(hashes.count)")
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Capsule().fill(.regularMaterial))
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
