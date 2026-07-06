import SwiftUI

struct SpeedLimitSection: View {
    let sectionTitle: String
    let footerText: String
    @Binding var dlLimitStr: String
    @Binding var ulLimitStr: String
    let onApply: () -> Void

    var body: some View {
        Section {
            LabeledContent(OrbixStrings.labelDownloadLimit) {
                HStack(spacing: 4) {
                    TextField(OrbixStrings.phNoLimit, text: $dlLimitStr)
                        .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                    Text("KB/s").font(.caption).foregroundStyle(.tertiary)
                }
            }
            LabeledContent(OrbixStrings.labelUploadLimit) {
                HStack(spacing: 4) {
                    TextField(OrbixStrings.phNoLimit, text: $ulLimitStr)
                        .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                    Text("KB/s").font(.caption).foregroundStyle(.tertiary)
                }
            }
            Button(OrbixStrings.btnApplyLimit) {
                AppHaptics.medium()
                onApply()
            }
        } header: {
            Text(sectionTitle)
        } footer: {
            Text(footerText)
        }
    }
}
