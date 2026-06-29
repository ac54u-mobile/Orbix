import SwiftUI

struct TorrentDetailFileSheet: View {
    let hash: String
    let files: [TorrentFile]
    @Binding var selectedFileIndices: Set<Int>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(files.indices, id: \.self) { index in
                    let file = files[index]
                    HStack(spacing: 10) {
                        Image(systemName: selectedFileIndices.contains(index) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selectedFileIndices.contains(index) ? AppColors.accent : AppColors.tertiaryLabel)
                            .onTapGesture {
                                if selectedFileIndices.contains(index) {
                                    selectedFileIndices.remove(index)
                                } else {
                                    selectedFileIndices.insert(index)
                                }
                            }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(file.name)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppColors.label)
                                .lineLimit(2)
                            Text(formatBytes(file.size))
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.secondaryLabel)
                        }

                        Spacer()

                        priorityBadge(file.priority)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppColors.mainBg)
            .navigationTitle(OrbixStrings.navFilePriority)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(OrbixStrings.btnCancel) { dismiss(); selectedFileIndices = [] }
                        .foregroundColor(AppColors.secondaryLabel)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !selectedFileIndices.isEmpty {
                        Menu {
                            Button { setPrio(0) } label: { Label(OrbixStrings.btnIgnore, systemImage: "nosign") }
                            Button { setPrio(1) } label: { Label(OrbixStrings.btnNormal, systemImage: "minus") }
                            Button { setPrio(6) } label: { Label(OrbixStrings.btnHigh, systemImage: "arrow.up") }
                            Button { setPrio(7) } label: { Label(OrbixStrings.btnMax, systemImage: "arrow.up.to.line") }
                        } label: {
                            Text("\(OrbixStrings.miscBatch) (\(selectedFileIndices.count))")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppColors.accent)
                        }
                    }
                    Button(OrbixStrings.btnDone) { dismiss(); selectedFileIndices = [] }
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.accent)
                }
            }
        }
    }

    private func priorityBadge(_ priority: Int) -> some View {
        let (label, color): (String, Color) = {
            switch priority {
            case 0: return (OrbixStrings.btnIgnore, AppColors.secondaryLabel)
            case 6: return (OrbixStrings.btnHigh, AppColors.accent)
            case 7: return (OrbixStrings.btnMax, AppColors.success)
            default: return (OrbixStrings.btnNormal, AppColors.tertiaryLabel)
            }
        }()
        return Text(label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.xs)
                    .fill(color.opacity(0.12))
            )
    }

    private func setPrio(_ priority: Int) {
        let indices = Array(selectedFileIndices)
        Task {
            try? await QBitApi.shared.setFilePriorities(hash, indices: indices, priority: priority)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            _ = try? await QBitApi.shared.getTorrentFiles(hash)
            await MainActor.run {
                selectedFileIndices = []
            }
        }
    }
}

#if DEBUG
struct FileSheetPreview: View {
    @State private var indices = Set([0])
    var body: some View {
        TorrentDetailFileSheet(
            hash: "abc",
            files: [
                TorrentFile(index: 0, name: "example.mp4", size: 1_073_741_824, progress: 0.8, priority: 1, isSeed: false),
                TorrentFile(index: 1, name: "example.nfo", size: 4096, progress: 1.0, priority: 1, isSeed: false)
            ],
            selectedFileIndices: $indices
        )
    }
}
#Preview { FileSheetPreview() }
#endif
