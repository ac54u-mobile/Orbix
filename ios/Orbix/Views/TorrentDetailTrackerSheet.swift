import SwiftUI

struct TorrentDetailTrackerSheet: View {
    let hash: String
    @Binding var trackers: [TorrentTracker]
    @State private var newTrackerURL = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 8) {
                        TextField("输入 Tracker URL ...", text: $newTrackerURL)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(AppColors.label)
                        Button {
                            guard !newTrackerURL.isEmpty else { return }
                            let urls = newTrackerURL.components(separatedBy: "\n").filter { !$0.isEmpty }
                            Task {
                                try? await QBitApi.shared.addTrackers(hash, urls: urls)
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                                await MainActor.run { newTrackerURL = "" }
                                if let t = try? await QBitApi.shared.getTorrentTrackers(hash) {
                                    await MainActor.run { trackers = t }
                                }
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(newTrackerURL.isEmpty ? AppColors.tertiaryLabel : AppColors.accent)
                        }
                        .disabled(newTrackerURL.isEmpty)
                    }
                } header: {
                    Text("添加 Tracker")
                }

                Section {
                    ForEach(trackers) { tracker in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Circle()
                                    .fill(trackerStatusColor(tracker.status))
                                    .frame(width: 8, height: 8)
                                Text(tracker.statusText)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(trackerStatusColor(tracker.status))
                                Spacer()
                                Text("种子 \(tracker.numSeeds)")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppColors.tertiaryLabel)
                            }
                            Text(tracker.url)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(AppColors.secondaryLabel)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 4)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Task {
                                    try? await QBitApi.shared.removeTrackers(hash, urls: [tracker.url])
                                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                                    if let t = try? await QBitApi.shared.getTorrentTrackers(hash) {
                                        await MainActor.run { trackers = t }
                                    }
                                }
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text("当前 Trackers (\(trackers.count))")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppColors.mainBg)
            .navigationTitle("Tracker 管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.accent)
                }
            }
        }
    }

    private func trackerStatusColor(_ status: Int) -> Color {
        switch status {
        case 0, 1: return AppColors.danger
        case 2, 4: return AppColors.success
        case 3: return AppColors.warning
        default: return AppColors.secondaryLabel
        }
    }
}
