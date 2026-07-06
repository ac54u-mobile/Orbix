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
                Section(OrbixStrings.sectionLocation) {
                    TextField(OrbixStrings.phNewSavePath, text: $newLocation)
                        .font(.system(.subheadline, design: .monospaced))

                    Button(OrbixStrings.btnApplyPath) {
                        AppHaptics.medium()
                        Task {
                            try? await QBitApi.shared.setTorrentLocation(hash, location: newLocation)
                            AppHaptics.success()
                        }
                    }
                    .disabled(newLocation.isEmpty)
                }

                Section(OrbixStrings.sectionRename) {
                    TextField(OrbixStrings.phRename, text: $newName)

                    Button(OrbixStrings.btnApplyName) {
                        Task {
                            try? await QBitApi.shared.renameTorrent(hash, name: newName)
                            AppHaptics.success()
                            dismiss()
                        }
                    }
                    .disabled(newName.isEmpty)
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
                        Label(OrbixStrings.btnToggleSequential, systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                    }
                } header: {
                    Text(OrbixStrings.sectionDownloadMode)
                } footer: {
                    Text(OrbixStrings.infoSequentialHint)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(OrbixStrings.navAdvancedControl)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(OrbixStrings.btnDone) { dismiss() }
                        .fontWeight(.semibold)
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
