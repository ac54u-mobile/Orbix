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
                        TextField(OrbixStrings.phTrackerURL, text: $newTrackerURL)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.primary)
                        Button {
                            guard !newTrackerURL.isEmpty else { return }
                            let urls = newTrackerURL.components(separatedBy: "\n").filter { !$0.isEmpty }
                            Task {
                                try? await QBitApi.shared.addTrackers(hash, urls: urls)
                                AppHaptics.success()
                                await MainActor.run { newTrackerURL = "" }
                                if let t = try? await QBitApi.shared.getTorrentTrackers(hash) {
                                    await MainActor.run { trackers = t }
                                }
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(newTrackerURL.isEmpty ? AppColors.textTertiary : AppColors.accentPrimary)
                        }
                        .disabled(newTrackerURL.isEmpty)
                    }
                } header: {
                    Text(OrbixStrings.sectionAddTracker)
                }

                Section {
                    ForEach(trackers) { tracker in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Circle()
                                    .fill(tracker.statusColor)
                                    .frame(width: 8, height: 8)
                                Text(tracker.statusText)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(tracker.statusColor)
                                Spacer()
                                Text("\(OrbixStrings.miscSeedsPrefix)\(tracker.numSeeds)")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppColors.textTertiary)
                            }
                            Text(tracker.url)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 4)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Task {
                                    try? await QBitApi.shared.removeTrackers(hash, urls: [tracker.url])
                                    AppHaptics.success()
                                    if let t = try? await QBitApi.shared.getTorrentTrackers(hash) {
                                        await MainActor.run { trackers = t }
                                    }
                                }
                            } label: {
                                Label(OrbixStrings.btnDelete, systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text("\(OrbixStrings.sectionCurrentTrackers) (\(trackers.count))")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppColors.gridBackgroundGradient)
            .navigationTitle(OrbixStrings.navTrackerManagement)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(OrbixStrings.btnDone) { dismiss() }
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.accentPrimary)
                }
            }
        }

    }
}

#if DEBUG
struct TrackerSheetPreview: View {
    @State private var trackers: [TorrentTracker] = [
        TorrentTracker(url: "udp://tracker.opentrackr.org:1337/announce", status: 2, tier: 0, numPeers: 42, numSeeds: 156, numLeeches: 23, numDownloaded: 5000, msg: ""),
        TorrentTracker(url: "https://tracker.example.com:443/announce", status: 4, tier: 1, numPeers: 10, numSeeds: 80, numLeeches: 5, numDownloaded: 1200, msg: "")
    ]
    var body: some View {
        TorrentDetailTrackerSheet(hash: "abc", trackers: $trackers)
    }
}
#Preview { TrackerSheetPreview() }
#endif
