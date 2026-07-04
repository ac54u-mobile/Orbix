import SwiftUI

struct TorrentDetailAdvancedSheet: View {
    let hash: String
    @Binding var newLocation: String
    @Binding var newName: String
    @Binding var dlLimitStr: String
    @Binding var ulLimitStr: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                    Text(OrbixStrings.miscModifyPath)
                        .sectionHeader()
                        TextField(OrbixStrings.phNewSavePath, text: $newLocation)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                    .padding(.vertical, 4)

                    Button {
                        AppHaptics.medium()
                        Task {
                            try? await QBitApi.shared.setTorrentLocation(hash, location: newLocation)
                            AppHaptics.success()
                        }
                    } label: {
                        Text(OrbixStrings.btnApplyPath)
                            .font(.system(size: 14, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: AppRadius.sm)
                                    .fill(newLocation.isEmpty ? AppColors.elevated : AppColors.accentPrimary)
                            )
                            .foregroundColor(newLocation.isEmpty ? AppColors.textSecondary : AppColors.textPrimary)
                    }
                    .disabled(newLocation.isEmpty)
                } header: {
                    Text(OrbixStrings.sectionLocation)
                }

                Section {
                    TextField(OrbixStrings.phRename, text: $newName)
                        .font(.system(size: 14))
                        .foregroundColor(.primary)

                    Button {
                        Task {
                            try? await QBitApi.shared.renameTorrent(hash, name: newName)
                            AppHaptics.success()
                            dismiss()
                        }
                    } label: {
                        Text(OrbixStrings.btnApplyName)
                            .font(.system(size: 14, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: AppRadius.sm)
                                    .fill(newName.isEmpty ? AppColors.elevated : AppColors.accentPrimary)
                            )
                            .foregroundColor(newName.isEmpty ? AppColors.textSecondary : AppColors.textPrimary)
                    }
                    .disabled(newName.isEmpty)
                } header: {
                    Text(OrbixStrings.sectionRename)
                }

                SpeedLimitSection(
                    sectionTitle: OrbixStrings.sectionSpeedLimit,
                    footerText: OrbixStrings.infoEmptyZeroHint,
                    dlLimitStr: $dlLimitStr,
                    ulLimitStr: $ulLimitStr,
                    onApply: {
                        Task {
                            let dl = (Int64(dlLimitStr) ?? -1)
                            let ul = (Int64(ulLimitStr) ?? -1)
                            if dl > 0 { try? await QBitApi.shared.setTorrentDownloadLimit(hash, limit: dl * 1024) }
                            else if dl == 0 { try? await QBitApi.shared.setTorrentDownloadLimit(hash, limit: 0) }
                            if ul > 0 { try? await QBitApi.shared.setTorrentUploadLimit(hash, limit: ul * 1024) }
                            else if ul == 0 { try? await QBitApi.shared.setTorrentUploadLimit(hash, limit: 0) }
                            AppHaptics.success()
                        }
                    }
                )

                Section {
                    Button {
                        AppHaptics.medium()
                        Task {
                            try? await QBitApi.shared.toggleSequentialDownload(hash)
                            AppHaptics.success()
                        }
                    } label: {
                        HStack {
                            Label(OrbixStrings.btnToggleSequential, systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.forward")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                } header: {
                    Text(OrbixStrings.sectionDownloadMode)
                } footer: {
                    Text(OrbixStrings.infoSequentialHint)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppColors.gridBackgroundGradient)
            .navigationTitle(OrbixStrings.navAdvancedControl)
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
struct AdvancedSheetPreview: View {
    @State private var loc = "/downloads"
    @State private var name = "test"
    @State private var dl = ""
    @State private var ul = ""
    var body: some View {
        TorrentDetailAdvancedSheet(hash: "abc", newLocation: $loc, newName: $name, dlLimitStr: $dl, ulLimitStr: $ul)
    }
}
#Preview { AdvancedSheetPreview() }
#endif
